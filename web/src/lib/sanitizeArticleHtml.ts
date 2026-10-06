import sanitizeHtml from 'sanitize-html';
import { normalizeImageCaptions } from './normalizeImageCaptions';

// Video providers whose iframes are allowed in public articles.
const ALLOWED_IFRAME_HOSTS = [
	'www.youtube.com',
	'youtube.com',
	'www.youtube-nocookie.com',
	'youtube-nocookie.com',
	'player.vimeo.com',
	'www.redditmedia.com',
	'embed.reddit.com',
];

/**
 * Sanitize parsed article HTML before showing it to anonymous visitors.
 *
 * Article content is third-party HTML and can also be edited by its owner
 * through the API, so on a public page it must be treated as untrusted:
 * the session of a logged-in visitor lives in localStorage on the same origin.
 *
 * Image + caption pairs are first turned into <figure>/<figcaption> (the
 * classes that mark captions are dropped by the sanitizer).
 */
export function sanitizeArticleHtml(html: string, baseUrl?: string): string {
	return sanitizeHtml(normalizeImageCaptions(html), {
		allowedTags: [
			...sanitizeHtml.defaults.allowedTags,
			'img', 'figure', 'figcaption', 'picture', 'source', 'iframe',
			'video', 'audio', 'del', 'ins', 'sup', 'sub', 'mark', 'small',
		],
		allowedAttributes: {
			a: ['href', 'title', 'name', 'target', 'rel'],
			img: ['src', 'srcset', 'sizes', 'alt', 'title', 'width', 'height', 'loading', 'decoding', 'referrerpolicy'],
			source: ['src', 'srcset', 'sizes', 'type', 'media'],
			iframe: ['src', 'width', 'height', 'allow', 'allowfullscreen', 'title', 'loading', 'referrerpolicy', 'sandbox'],
			video: ['src', 'controls', 'poster', 'width', 'height', 'preload'],
			audio: ['src', 'controls', 'preload'],
			td: ['colspan', 'rowspan'],
			th: ['colspan', 'rowspan', 'scope'],
			ol: ['start', 'reversed', 'type'],
			// no `id`: avoids DOM clobbering of globals on our own origin
			'*': ['lang', 'dir'],
		},
		// Only the CMS caption classes used by the .html-chunk image-card styles
		allowedClasses: { '*': ['wp-caption', 'wp-caption-text'] },
		allowedSchemes: ['http', 'https', 'mailto'],
		allowedSchemesByTag: { img: ['http', 'https', 'data'] },
		allowedIframeHostnames: ALLOWED_IFRAME_HOSTS,
		allowIframeRelativeUrls: false,
		allowProtocolRelative: false,
		transformTags: {
			a: (tagName, attribs) => {
				const href = attribs.href ? resolveUrl(attribs.href, baseUrl) : undefined;
				const isAnchor = href?.startsWith('#');
				return {
					tagName,
					attribs: {
						...attribs,
						...(href ? { href } : {}),
						...(isAnchor ? {} : { target: '_blank', rel: 'noopener noreferrer nofollow ugc' }),
					},
				};
			},
			img: (tagName, attribs) => ({
				tagName,
				attribs: {
					...attribs,
					...(attribs.src ? { src: resolveUrl(attribs.src, baseUrl) } : {}),
					loading: 'lazy',
					decoding: 'async',
					referrerpolicy: 'no-referrer',
				},
			}),
			iframe: (tagName, attribs) => ({
				tagName,
				attribs: {
					...attribs,
					loading: 'lazy',
					referrerpolicy: 'strict-origin-when-cross-origin',
					sandbox: 'allow-scripts allow-same-origin allow-presentation allow-popups',
				},
			}),
		},
		// Iframes from non-allowed hosts lose their src: drop them entirely
		exclusiveFilter: (frame) => frame.tag === 'iframe' && !frame.attribs.src,
	});
}

function resolveUrl(url: string, baseUrl?: string): string {
	if (!baseUrl || url.startsWith('#') || url.startsWith('data:') || url.startsWith('mailto:')) return url;
	try {
		return new URL(url, baseUrl).toString();
	} catch {
		return url;
	}
}
