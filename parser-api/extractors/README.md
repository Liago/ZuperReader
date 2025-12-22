# Custom Extractors for Mercury Parser

This directory contains custom extractors for specific websites that require special parsing logic.

## Structure

Each extractor is a separate JavaScript file named after the domain it handles (e.g., `comingsoon.it.js`, `unaparolaalgiorno.it.js`).

## Adding a New Extractor

1. **Create a new file** named after the domain (e.g., `example.com.js`)

2. **Define the extractor configuration** following this template:

```javascript
/**
 * Custom extractor for example.com
 * Description of what this extractor handles
 */
module.exports = {
	domain: 'www.example.com',
	title: {
		selectors: [
			'h1.article-title',
			'h1',
			['meta[property="og:title"]', 'value'],
		],
	},
	author: {
		selectors: [
			'.author-name',
			['meta[name="author"]', 'value'],
		],
	},
	date_published: {
		selectors: [
			['time[datetime]', 'datetime'],
			['meta[property="article:published_time"]', 'value'],
		],
	},
	lead_image_url: {
		selectors: [
			['meta[property="og:image"]', 'value'],
		],
	},
	content: {
		selectors: [
			'article .content',
			'article',
		],
		transforms: {
			// Add custom transformations if needed
			// Example: convert lazy-loaded images
			'img[data-src]': ($node) => {
				const dataSrc = $node.attr('data-src');
				if (dataSrc) {
					$node.attr('src', dataSrc);
					$node.removeAttr('data-src');
				}
			},
		},
		clean: [
			// Selectors for elements to remove
			'.ads',
			'.social-share',
			'script',
			'style',
		],
	},
	excerpt: {
		selectors: [
			['meta[name="description"]', 'value'],
			['meta[property="og:description"]', 'value'],
		],
	},
};
```

3. **Register the extractor** in `index.js`:

```javascript
// Add the require statement
const exampleCom = require('./example.com.js');

// Add to the extractors array
const extractors = [
	comingsoonIt,
	unaparolaalgiorno,
	exampleCom, // Add your extractor here
];
```

4. **Test the extractor** by running the parse function with a URL from the target domain

## Extractor Configuration Reference

### Selectors

Selectors can be:
- A CSS selector string: `'h1.title'`
- An array with selector and attribute: `['meta[property="og:title"]', 'value']`
- Multiple fallback selectors (tried in order): `['h1.title', 'h1', ['meta[property="og:title"]', 'value']]`

### Transforms

Transforms allow you to modify the DOM before extraction. Each transform is a function that receives a Cheerio node:

```javascript
transforms: {
	'selector': ($node) => {
		// Modify $node here
	},
}
```

### Clean

An array of CSS selectors for elements to remove from the content before extraction.

## Current Extractors

- **comingsoon.it** - Italian movie/TV news site with lazy-loaded videos and images
- **unaparolaalgiorno.it** - Italian word-of-the-day site with minimal content cleaning

## Resources

- [Mercury Parser Documentation](https://github.com/postlight/mercury-parser)
- [Custom Extractor Guide](https://github.com/postlight/mercury-parser/blob/master/src/extractors/custom/README.md)
