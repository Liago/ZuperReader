export const UnaparolaalgiornoltExtractor = {
  domain: 'unaparolaalgiorno.it',

  title: {
    selectors: [
      'article.word h1',
      'h1',
      ['meta[property="og:title"]', 'value'],
    ],
  },

  author: {
    selectors: [
      // Author is embedded in .word-datapub text, fallback to site name
      ['meta[name="author"]', 'value'],
    ],
  },

  date_published: {
    selectors: [
      ['meta[property="article:published_time"]', 'value'],
      '.word-datapub',
    ],
  },

  lead_image_url: {
    selectors: [
      ['meta[property="og:image"]', 'value'],
    ],
  },

  content: {
    selectors: [
      // Main content is in .word-commento, but we want full .content
      'article.word .content',
      '.word .content',
      'article.word',
    ],

    // Clean up elements that shouldn't be in the content
    clean: [
      '.social-share-container',
      '.social-share',
      '#quiz-section-container',
      '#daily-quiz-section',
      'script',
      'style',
      '.newsletter-box',
      '#comments-container',
      '#next-section-container',
    ],
  },

  excerpt: {
    selectors: [
      ['meta[name="description"]', 'value'],
      ['meta[property="og:description"]', 'value'],
      '.word-significato',
    ],
  },
};
