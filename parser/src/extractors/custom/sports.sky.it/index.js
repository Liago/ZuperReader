export const SportsSkyItExtractor = {
    domain: 'sports.sky.it',

    title: {
        selectors: [
            'h1.c-hero__title-content',
            ['meta[property="og:title"]', 'value'],
        ],
    },

    author: {
        selectors: [
            '.c-hero__author-name',
            ['meta[name="author"]', 'value'],
        ],
    },

    date_published: {
        selectors: [
            '.c-hero__date',
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
            '.l-grid__main',
        ],

        clean: [
            '.c-hero',
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
