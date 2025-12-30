const SportsSkyItExtractor = {
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

    // Content cleaning
    content: {
        selectors: [
            '.l-grid__main', // Specific to layout, cleaner than generic article
            'article',
            '.c-article-body',
            '.c-article-abstract', // Fallback for short articles/video pages
        ],

        clean: [
            '.c-hero__author-name',
            '.c-intro', // Remove the header/hero section to avoid duplicate title/image
            '.c-social-share',
            '.j-social-share',
            '.c-box-marketing',
            '.c-banner-no-cookies',
            '.video-playlist-inline',
            '.s-native-sponsored',
            '.s-social-connection', // "Segui tutti gli aggiornamenti..."
            '.s-tag-section',
            '.s-outbrain',
            '.j-outbrain',
            '.c-personalization-widget',
            '#autoPushNotifications',
            'p:contains("selectBoxes")',
            'p:contains("SkySport")',
        ],
    },
};

module.exports = SportsSkyItExtractor;
