import { load, type CheerioAPI } from 'cheerio';
import type { AnyNode, Element } from 'domhandler';

// Class/id fragments that CMSs use for image captions and photo credits.
const CAPTION_HINT = /(caption|didascalia|credit|legend|photo-?text|image-?text|img-?text|foto-?text)/i;

// Wrappers that pair an image with its caption (WordPress attachments, CMS image blocks).
const IMAGE_WRAPPER_HINT = /(attachment_|wp-caption|image|img|photo|foto|media|picture)/i;

// Plain-text captions in the press style "Description (Credit)" or "Foto: ...".
const CREDIT_SUFFIX = /\([^()]{2,80}\)\s*$/;
const CREDIT_PREFIX = /^(foto|photo|credit|credits|immagine|image|fonte|source)\s*[:©]/i;

const MAX_CAPTION_LENGTH = 320;
const BLOCK_TAGS = new Set(['p', 'div', 'span', 'small', 'em', 'i', 'figcaption', 'cite']);

/**
 * Turn the image + caption pairs found in parsed article HTML into
 * <figure><img><figcaption> so they render as a card with a visible caption.
 *
 * Must run before sanitizeArticleHtml: the sanitizer drops classes and ids,
 * which are the main hint that a paragraph is a caption.
 */
export function normalizeImageCaptions(html: string): string {
	if (!html.includes('<img')) return html;

	const $ = load(html, null, false);

	wrapCaptionContainers($);
	wrapImageWithFollowingCaption($);

	return $.html();
}

/** A single element holding only an image and its caption (e.g. div#attachment_123.wp-caption). */
function wrapCaptionContainers($: CheerioAPI): void {
	$('div, p, span').each((_, node) => {
		const el = node as Element;
		if ($(el).closest('figure').length > 0) return;
		if (!IMAGE_WRAPPER_HINT.test(hintOf(el))) return;
		if ($(el).find('img').length !== 1) return;

		const children = $(el).children().toArray() as Element[];
		const others = children.filter((child) => child.name !== 'img' && $(child).find('img').length === 0);
		if (others.length !== 1 || children.length !== 2) return;

		const caption = others[0];
		if (!isCaptionCandidate($, caption, true)) return;

		el.name = 'figure';
		caption.name = 'figcaption';
	});
}

/** An image (alone in its block) immediately followed by a caption sibling. */
function wrapImageWithFollowingCaption($: CheerioAPI): void {
	$('img').each((_, node) => {
		const img = node as Element;
		if ($(img).closest('figure').length > 0) return;

		const block = imageBlockOf($, img);
		const next = nextElementSibling(block);
		if (!next || $(next).find('img').length > 0) return;

		const hinted = CAPTION_HINT.test(hintOf(next)) || next.name === 'figcaption';
		if (!isCaptionCandidate($, next, hinted)) return;

		const figure = $('<figure></figure>');
		$(block).before(figure);
		if (['img', 'a', 'picture'].includes(block.name)) {
			figure.append($(block));
		} else {
			// p/div/span that only wrapped the image: keep its content, drop the wrapper
			figure.append($(block).contents());
			$(block).remove();
		}

		figure.append($('<figcaption></figcaption>').append($(next).contents()));
		$(next).remove();
	});
}

/**
 * The outermost element that contains only this image (p > a > img, picture > img),
 * so the following sibling is compared at the right level.
 */
function imageBlockOf($: CheerioAPI, img: Element): Element {
	let current: Element = img;
	while (current.parent && current.parent.type === 'tag') {
		const parent = current.parent as Element;
		if (!['p', 'a', 'picture', 'div', 'span'].includes(parent.name)) break;
		const hasOtherContent =
			$(parent).find('img').length > 1 ||
			$(parent).text().trim().length > 0 ||
			$(parent).children().toArray().some((child) => child !== current && (child as Element).name !== 'source');
		if (hasOtherContent) break;
		current = parent;
	}
	return current;
}

function nextElementSibling(el: Element): Element | null {
	let sibling: AnyNode | null = el.next;
	while (sibling) {
		if (sibling.type === 'tag') return sibling as Element;
		if (sibling.type === 'text' && (sibling as unknown as { data: string }).data.trim().length > 0) return null;
		sibling = sibling.next;
	}
	return null;
}

function isCaptionCandidate($: CheerioAPI, el: AnyNode, hinted: boolean): boolean {
	if (el.type !== 'tag') return false;
	const element = el as Element;
	if (!BLOCK_TAGS.has(element.name)) return false;

	const text = $(element).text().replace(/\s+/g, ' ').trim();
	if (!text || text.length > MAX_CAPTION_LENGTH) return false;
	if (hinted) return true;

	// Without a class hint, accept only clear caption shapes.
	const onlyEmphasis =
		element.children.length > 0 &&
		element.children.every(
			(child) =>
				(child.type === 'text' && (child as unknown as { data: string }).data.trim() === '') ||
				(child.type === 'tag' && ['em', 'i', 'small', 'cite'].includes((child as Element).name))
		);

	return onlyEmphasis || ['small', 'figcaption', 'cite'].includes(element.name) || CREDIT_SUFFIX.test(text) || CREDIT_PREFIX.test(text);
}

function hintOf(el: Element): string {
	return `${el.attribs?.class ?? ''} ${el.attribs?.id ?? ''}`;
}
