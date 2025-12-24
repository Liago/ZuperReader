
const cheerio = require('cheerio');
const fs = require('fs');
const extractor = require('./ultimouomo.it.js');

const html = fs.readFileSync('./test_fixture.html', 'utf8');
const $ = cheerio.load(html);

// Run transforms
console.log('Found scripts:', $('script').length);
$('script').each((i, el) => {
    console.log(`Script ${i} length:`, $(el).html().length);
    console.log(`Script ${i} content start:`, $(el).html().substring(0, 50));
});

// Run transforms
if (extractor.content.transforms) {
    Object.keys(extractor.content.transforms).forEach(selector => {
        const transform = extractor.content.transforms[selector];
        if (selector === 'body') {
            transform($('body'), $);
        } else {
            $(selector).each((i, el) => transform($(el), $));
        }
    });
}

// Check extraction
console.log('Title:', $('h1').text() || $('meta[property="og:title"]').attr('content'));

// Helper to check selectors
function get(conf) {
    for (const sel of conf.selectors) {
        if (Array.isArray(sel)) {
            const val = $(sel[0]).attr(sel[1]);
            if (val) return val;
        } else {
            const val = $(sel).text();
            if (val) return val;
        }
    }
}

console.log('Author:', get(extractor.author));
console.log('Published:', get(extractor.date_published));
console.log('Image:', get(extractor.lead_image_url));

// Content
let content = '';
for (const sel of extractor.content.selectors) {
    if ($(sel).length > 0) {
        content = $(sel).html();
        break;
    }
}
console.log('Content length:', content ? content.length : 0);
if (content) {
    console.log('Content start:', content.substring(0, 200));
} else {
    console.log('No content found');
}
