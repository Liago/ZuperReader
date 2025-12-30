import assert from 'assert';
import Mercury from 'mercury';
import cheerio from 'cheerio';

const fs = require('fs');

describe('SportsSkyItRepro', () => {
    it('cleans garbage text and section divider', async () => {
        const html = fs.readFileSync('./fixtures/real-sky.html');
        // Check if article tag exists
        if (html.includes('<article')) {
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
