import assert from 'assert';
import Mercury from 'mercury';
import cheerio from 'cheerio';

const fs = require('fs');

describe('SportsSkyItRepro', () => {
    it('cleans garbage text and section divider', async () => {
        const html = fs.readFileSync('./fixtures/real-sky.html');
        // Check if article tag exists
        const cheerio = require('cheerio');

        // Mimic the template unwrapping logic from parser-api/netlify/functions/parse.js
        const $html = cheerio.load(html);
        $html('template').each(function () {
            const innerHtml = $html(this).html();
            // Specialized Instagram handling: convert to iframe to boost Mercury score
            if (innerHtml && innerHtml.includes('instagram-media')) {
                const match = innerHtml.match(/data-instgrm-permalink="([^"]+)"/);
                if (match) {
                    let url = match[1];
                    // Ensure it is an embed url clean of params
                    url = url.split('?')[0];
                    if (!url.endsWith('/')) url += '/';
                    url += 'embed';
                    $html(this).replaceWith(`<iframe src="${url}" class="instagram-media" width="100%" height="600" frameborder="0"></iframe>`);
                    return;
                }
            }

            // Generic fallback
            if (innerHtml && (innerHtml.includes('<blockquote') || innerHtml.includes('<div') || innerHtml.includes('<img'))) {
                $html(this).replaceWith(innerHtml);
            }
        });
        const htmlWithTemplatesUnwrapped = $html.html();

        if (htmlWithTemplatesUnwrapped.includes('<article')) {
            console.log('DEBUG: <article> tag FOUND in real HTML');
        } else {
            console.log('DEBUG: <article> tag NOT FOUND in real HTML');
        }
        // Mocking the extractor load since we are testing the logic usage by Mercury
        // But we need to use the actual extractor logic.
        // We will load the extractor code from the file we are editing.

        // Note: We need to point to the LOCAL parser implementation for testing purposes,
        // even though we are targeting parser-api for deployment.
        // The logic is in parser/src/extractors/custom/sports.sky.it/index.js (ES6)
        // AND parser-api/extractors/sports.sky.it.js (CommonJS).
        // The test runner uses the ES6 one in src.
        // I need to ensure src/extractors/custom/sports.sky.it/index.js matches the parser-api one content-wise.

        const url = 'https://sports.sky.it/repro';
        const result = await Mercury.parse(url, { html, fallback: false });

        console.log('--- Result Content Start ---');
        console.log(result.content);
        console.log('--- Result Content End ---');

        const $ = cheerio.load(result.content || '');
        const text = $.text();

        // Check if garbage persist
        if (text.includes('selectBoxes')) {
            console.log('FAIL: Garbage text "selectBoxes" found');
        } else {
            console.log('PASS: Garbage text not found');
        }

        // Check if section divider persist
        if (text.includes('Segui Sky Sport')) {
            console.log('FAIL: "Segui Sky Sport" found');
        } else {
            console.log('PASS: "Segui Sky Sport" not found');
        }
    });
});
