export const SportsSkyItExtractor = {
    domain: 'sports.sky.it',

    title: {
        selectors: [
            'h1.c-hero__title-content',
            ['meta[name="og:title"]', 'content'],
        ],
    },

    author: {
        selectors: [
            '.c-hero__author-name',
            ['meta[name="author"]', 'content'],
        ],
    },

    date_published: {
        selectors: [
            ['meta[name="article:published_time"]', 'content'],
            '.c-hero__date',
        ],
    },

    lead_image_url: {
        selectors: [
            ['meta[name="og:image"]', 'content'],
            ['.c-hero__media img', 'src'],
        ],
    },

    content: {
        selectors: [
            '.l-grid__main',
        ],

        clean: [
            '.c-hero__title-content',
            '.c-hero__author-name',
            '.c-hero__date',
            '.c-adv',
            '.c-social',
            '.c-section-title',
            '.c-nav-utility',
            '.c-global-nav',
            '.c-local-nav',
            '.c-footer',
            'script',
            'style',
            '.c-banner-marketing',
            '.c-paywall',
            '.c-section-divider',
            '.c-reading-progress-bar',
        ],
    },
};
