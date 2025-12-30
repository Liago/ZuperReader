import assert from 'assert';
import URL from 'url';
import cheerio from 'cheerio';
import Mercury from 'mercury';
import getExtractor from 'extractors/get-extractor';
import { excerptContent } from 'utils/text';

const fs = require('fs');

describe('SportsSkyItExtractor', () => {
    describe('initial test case', () => {
        let result;
        let url;
        beforeAll(() => {
            url = 'https://sports.sky.it/nba/2025/12/30/lebron-james-birthday';
            const html = fs.readFileSync('./fixtures/sports.sky.it.html');
            result = Mercury.parse(url, { html, fallback: false });
        });

        it('is selected properly', () => {
            // This test checks if the correct extractor is selected for the domain
            const extractor = getExtractor(url);
            assert.equal(extractor.domain, URL.parse(url).hostname);
        });

        it('returns the title', async () => {
            const { title } = await result;
            assert.equal(title, 'Buon compleanno LeBron, il super veterano oggi compie 41 anni: la sua incredibile storia');
        });

        it('returns the author', async () => {
            const { author } = await result;
            assert.equal(author, 'Sky Sport');
        });

        it('returns the date_published', async () => {
            const { date_published } = await result;
            // Mercury might convert the date format, let's verify what it returns
            // The sample date is 30/12/2025.
            // Depending on locale/parsing, this might be parsed or returned as string.
            // The meta tag has 2025-12-30T00:00:00Z which is safer.
            assert.equal(date_published, '2025-12-30T00:00:00.000Z');
        });

        it('returns the lead_image_url', async () => {
            const { lead_image_url } = await result;
            assert.equal(lead_image_url, 'https://sport.sky.it/assets/images/lebron.jpg');
        });

        it('returns the content', async () => {
            const { content } = await result;
            const $ = cheerio.load(content || '');
            const text = $.text().trim();

            assert.ok(text.includes('James raccontato da La Giornata Tipo per Sky Sport'));
            assert.ok(text.includes('Una carriera lunga, anzi lunghissima...'));
            assert.ok(!text.includes('Ad content')); // Adv should be cleaned
        });
    });
});
