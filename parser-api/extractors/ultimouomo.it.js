/**
 * Custom extractor for ultimouomo.it
 * Handles Next.js hydration data extraction for content
 */

module.exports = {
    domain: 'ultimouomo.it',
    title: {
        selectors: [
            'h1',
            ['meta[property="og:title"]', 'value'],
            ['meta[name="twitter:title"]', 'value'],
            '.extracted-title',
        ],
    },
    author: {
        selectors: [
            ['meta[name="author"]', 'value'],
            '.author-name',
            '.extracted-author',
        ],
    },
    date_published: {
        selectors: [
            ['meta[property="article:published_time"]', 'value'],
            ['time[datetime]', 'datetime'],
            '.extracted-date',
        ],
    },
    lead_image_url: {
        selectors: [
            ['meta[property="og:image"]', 'value'],
            ['meta[name="twitter:image"]', 'value'],
            '.extracted-image', // if we extract it specifically
        ],
    },
    excerpt: {
        selectors: [
            ['meta[property="og:description"]', 'value'],
            ['meta[name="description"]', 'value'],
        ],
    },
    content: {
        selectors: [
            '.extracted-content',
            '.slug_post__WJWtL',
            'article',
        ],
        transforms: {
            'body': ($node, $) => {
                // If we already have content, do nothing (fast path)
                if ($('.slug_post__WJWtL').length > 0 && $('.slug_post__WJWtL').text().trim().length > 50) {
                    return;
                }

                const scriptContent = [];
                $('script').each((i, el) => {
                    const html = $(el).html();
                    if (html && html.includes('self.__next_f.push')) {
                        scriptContent.push(html);
                    }
                });

                if (scriptContent.length > 0) {
                    let foundData = false;
                    // We'll iterate and try to find the "post" object
                    // Pattern: "post":{ ... "content":[ ... ] ... }
                    // OR "content":[ ... ] if it's top level (unlikely)

                    // Strategy: Find strings that look like our target JSON and parse them

                    for (const script of scriptContent) {
                        // Extract the string argument of push([id, "STRING"])
                        // Simple regex for the push call structure
                        // Use [\s\S] to match newlines as the script content might span multiple lines
                        const pushRegex = /self\.__next_f\.push\(\[[^,]+,\s*"([\s\S]*)"\]\)/;
                        const match = pushRegex.exec(script);

                        if (match && match[1]) {
                            // The giant string
                            let bigString = match[1];
                            // Try to parse the string to unescape it correctly
                            try {
                                // If the capture contains invalid newlines for a JSON string, escape them
                                // (though strictly the source JS should be valid, cheerio might give us raw newlines)
                                // We wrap in quotes to parse as a string
                                bigString = JSON.parse('"' + bigString.replace(/\n/g, '\\n') + '"');
                            } catch (e) {
                                // Fallback or stick with raw if parse fails (unlikely if valid JS)
                                // Try manual basic unescape as fallback
                                bigString = bigString.replace(/\\"/g, '"').replace(/\\\\/g, '\\');
                            }

                            // Now look for "content":[ ...
                            const contentIndex = bigString.indexOf('"content":[');
                            if (contentIndex !== -1) {
                                // Start parsing Array from contentIndex + 10 (length of "content":)
                                const arrayStartIndex = contentIndex + 10;
                                let bracketCount = 0;
                                let arrayString = '';
                                let started = false;

                                for (let i = arrayStartIndex; i < bigString.length; i++) {
                                    const char = bigString[i];
                                    if (char === '[') {
                                        bracketCount++;
                                        started = true;
                                    } else if (char === ']') {
                                        bracketCount--;
                                    }

                                    arrayString += char;

                                    if (started && bracketCount === 0) {
                                        break;
                                    }
                                }

                                // Try to parse the content array
                                try {
                                    const blocks = JSON.parse(arrayString);
                                    if (Array.isArray(blocks)) {
                                        let fullContent = '';
                                        blocks.forEach(block => {
                                            if (block._type === 'block' && block.children) {
                                                const pText = block.children.map(c => c.text).join(' ');
                                                fullContent += `<p>${pText}</p>\n`;
                                            } else if (block._type === 'image' && block.asset) {
                                                // Image REF. Need to resolve URL?
                                                if (block.asset._ref) {
                                                    const parts = block.asset._ref.split('-');
                                                    if (parts.length >= 3) {
                                                        const id = parts[1];
                                                        const dim = parts[2];
                                                        const ext = parts[3];
                                                        const url = `https://cdn.sanity.io/images/ba9gdw6b/production/${id}-${dim}.${ext}`;
                                                        fullContent += `<figure><img src="${url}" /><figcaption>${block.caption || ''}</figcaption></figure>\n`;
                                                    }
                                                }
                                            } else if (block._type === 'gallery' && block.images) {
                                                block.images.forEach(img => {
                                                    if (img.asset?._ref) {
                                                        const parts = img.asset._ref.split('-');
                                                        if (parts.length >= 3) {
                                                            const id = parts[1];
                                                            const dim = parts[2];
                                                            const ext = parts[3];
                                                            const url = `https://cdn.sanity.io/images/ba9gdw6b/production/${id}-${dim}.${ext}`;
                                                            fullContent += `<figure><img src="${url}" /><figcaption>${img.caption || ''}</figcaption></figure>\n`;
                                                        }
                                                    }
                                                });
                                            }
                                        });

                                        if (fullContent.length > 0) {
                                            $('body').append(`<div class="extracted-content">${fullContent}</div>`);
                                            foundData = true;
                                        }
                                    }
                                } catch (e) {
                                    // silently ignore
                                }
                            }

                            // Extract Metadata (Author, Date) from the same big element if available
                            if (!foundData) continue; // Only continue if we found content

                            const firstNameMatch = bigString.match(/"firstName":"(.*?)"/);
                            const lastNameMatch = bigString.match(/"lastName":"(.*?)"/);
                            if (firstNameMatch && lastNameMatch) {
                                const author = `${firstNameMatch[1]} ${lastNameMatch[1]}`;
                                $('body').append(`<div class="extracted-author">${author}</div>`);
                            }

                            const dateMatch = bigString.match(/"date":"(.*?)"/);
                            if (dateMatch) {
                                $('body').append(`<div class="extracted-date">${dateMatch[1]}</div>`);
                            }

                            // Extract Title if not present
                            const titleMatch = bigString.match(/"title":"(.*?)"/);
                            if (titleMatch) {
                                $('body').append(`<div class="extracted-title">${titleMatch[1]}</div>`);
                            }
                        }
                    }
                }
            }
        },
        clean: [
            'script',
            'style',
        ],
    },
};
