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

// Array of all custom extractors
const extractors = [
	comingsoonIt,
	unaparolaalgiorno,
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
