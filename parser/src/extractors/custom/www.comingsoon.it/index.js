export const WwwComingsoonItExtractor = {
  domain: 'www.comingsoon.it',

  title: {
    selectors: [
      'h1.h1',
      'h1',
      ['meta[property="og:title"]', 'value'],
    ],
  },

  author: {
    selectors: [
      '#author',
      '.art-personal a[rel="publisher"]',
      ['meta[name="author"]', 'value'],
    ],
  },

  date_published: {
    selectors: [
      ['time[datetime]', 'datetime'],
      ['meta[property="article:published_time"]', 'value'],
      'time',
    ],
  },

  lead_image_url: {
    selectors: [
      ['meta[property="og:image"]', 'value'],
    ],
  },

  content: {
    selectors: [
      '#contenuto-articolo',
      'article',
    ],

    // Transform lazy-loaded iframes and images
    transforms: {
      // Convert lazy-loaded iframes (videos) to regular iframes
      'iframe[data-src]': $node => {
        const dataSrc = $node.attr('data-src');
        if (dataSrc) {
          $node.attr('src', dataSrc);
          $node.removeAttr('data-src');
          $node.removeAttr('class'); // Remove lazyload class
        }
      },

      // Convert lazy-loaded images to regular images
      'img[data-src]': $node => {
        const dataSrc = $node.attr('data-src');
        if (dataSrc) {
          $node.attr('src', dataSrc);
          $node.removeAttr('data-src');
          $node.removeAttr('class'); // Remove lazyload class
        }
      },

      // Handle picture elements with lazy-loaded sources
      'picture source[data-srcset]': $node => {
        const dataSrcset = $node.attr('data-srcset');
        if (dataSrcset) {
          $node.attr('srcset', dataSrcset);
          $node.removeAttr('data-srcset');
          $node.removeAttr('class');
        }
      },

      // Clean up span containers around iframes
      'span.contenitore-iframe': $node => {
        const $iframe = $node.find('iframe');
        if ($iframe.length > 0) {
          $node.replaceWith($iframe);
        }
      },
    },

    // Remove unwanted elements from content
    clean: [
      '.advCollapse',
      '.boxAdv',
      '.gptslot',
      '.art-social',
      '.art-tag',
      '.art-personal',
      '.tasti-social-top',
      '.cs-btn',
      'script',
      'style',
      'noscript',
      '.liveBlog_refresh',
      '#liveblog',
      '.divider-dark',
      '.breadcrumb',
    ],
  },

  excerpt: {
    selectors: [
      ['meta[name="description"]', 'value'],
      ['meta[property="og:description"]', 'value'],
      '.art-subtitle',
      'p.art-subtitle',
    ],
  },

  dek: {
    selectors: [
      '.art-subtitle',
      'p.art-subtitle',
    ],
  },
};
