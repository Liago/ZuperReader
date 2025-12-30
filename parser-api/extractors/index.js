/**
 * Custom extractors for Mercury Parser
 *
 * To add a new extractor:
 * 1. Create a new file in this directory (e.g., example.com.js)
 * 2. Export the extractor configuration object
 * 3. Add it to the extractors array below
 */

const comingsoonIt = require('./comingsoon.it.js');
const unaparolaalgiorno = require('./unaparolaalgiorno.it.js');
const ultimouomo = require('./ultimouomo.it.js');
const sportsSkyIt = require('./sports.sky.it.js');

// Create aliases for other domains
const ultimouomoCom = { ...ultimouomo, domain: 'ultimouomo.com' };
const ultimouomoWwwCom = { ...ultimouomo, domain: 'www.ultimouomo.com' };
const ultimouomoWwwIt = { ...ultimouomo, domain: 'www.ultimouomo.it' };
const sportSkyIt = { ...sportsSkyIt, domain: 'sport.sky.it' }; // Alias for sport.sky.it without 's'

// Array of all custom extractors
const extractors = [
	comingsoonIt,
	unaparolaalgiorno,
	ultimouomo,
	ultimouomoCom,
	ultimouomoWwwCom,
	ultimouomoWwwIt,
	sportsSkyIt,
	sportSkyIt,
];

/**
 * Register all custom extractors with Mercury Parser
 * @param {Object} Mercury - Mercury Parser instance
 */
function registerExtractors(Mercury) {
	extractors.forEach(extractor => {
		Mercury.addExtractor(extractor);
		console.log(`Registered extractor for: ${extractor.domain}`);
	});
}

module.exports = {
	extractors,
	registerExtractors,
};
