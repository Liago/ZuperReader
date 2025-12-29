import Parser from 'rss-parser';
import { XMLParser } from 'fast-xml-parser';

export interface FeedItem {
  title?: string;
  link?: string;
  pubDate?: string;
  author?: string;
  creator?: string; // RSS feeds sometimes use dc:creator instead of author
  content?: string;
  contentSnippet?: string;
  isoDate?: string;
  guid?: string; // Unique identifier for the feed item
  imageUrl?: string; // Extracted thumbnail/image URL
}

export interface FeedData {
  title?: string;
  description?: string;
  link?: string;
  feedUrl?: string; // The URL of the RSS feed itself
  items: FeedItem[];
  image?: {
    link?: string;
    url?: string;
    title?: string;
  };
}

export interface OpmlOutline {
  text?: string;
  title?: string;
  type?: string;
  xmlUrl?: string; // RSS feed URL
  htmlUrl?: string;
  outlines?: OpmlOutline[]; // For nested folders
}

// Initialize parser with custom fields if needed
const parser = new Parser({
  customFields: {
    item: [
      ['content:encoded', 'contentEncoded'],
      ['media:content', 'mediaContent'],
      ['media:thumbnail', 'mediaThumbnail'],
      ['enclosure', 'enclosure'],
    ],
  },
});

/**
 * Extracts image URL from various sources in RSS feed items
 * Priority: media:thumbnail > media:content > enclosure > img in content
 */
function extractImageUrl(item: any): string | undefined {
  // 1. Try media:thumbnail (most common for thumbnails)
  if (item.mediaThumbnail) {
    const thumbnail = Array.isArray(item.mediaThumbnail)
      ? item.mediaThumbnail[0]
      : item.mediaThumbnail;
    if (thumbnail?.$ && thumbnail.$.url) {
      return thumbnail.$.url;
    }
    if (typeof thumbnail === 'string') {
      return thumbnail;
    }
  }

  // 2. Try media:content
  if (item.mediaContent) {
    const media = Array.isArray(item.mediaContent)
      ? item.mediaContent[0]
      : item.mediaContent;
    if (media?.$ && media.$.url) {
      return media.$.url;
    }
  }

  // 3. Try enclosure with image type
  if (item.enclosure) {
    const enclosure = Array.isArray(item.enclosure)
      ? item.enclosure[0]
      : item.enclosure;
    if (enclosure?.$ && enclosure.$.type?.startsWith('image/')) {
      return enclosure.$.url;
    }
    // Some feeds have enclosure as object directly
    if (enclosure?.url && enclosure?.type?.startsWith('image/')) {
      return enclosure.url;
    }
  }

  // 4. Try to find first image in content
  const content = item['content:encoded'] || item.content || '';
  const imgMatch = content.match(/<img[^>]+src=["']([^"']+)["']/i);
  if (imgMatch && imgMatch[1]) {
    return imgMatch[1];
  }

  return undefined;
}

/**
 * Fetches and parses an RSS feed from a URL
 * This should only be called server-side to avoid CORS issues
 */
export async function fetchFeed(url: string): Promise<FeedData> {
  try {
    const feed = await parser.parseURL(url);

    // Transform to our interface if needed, or just return as is
    // rss-parser output is very similar to our FeedData interface
    return {
      title: feed.title,
      description: feed.description,
      link: feed.link,
      feedUrl: url,
      items: feed.items.map(item => ({
        title: item.title,
        link: item.link,
        pubDate: item.pubDate,
        author: item.creator || (item as any).author,
        content: item['content:encoded'] || item.content,
        contentSnippet: item.contentSnippet,
        isoDate: item.isoDate,
        imageUrl: extractImageUrl(item),
      })),
      image: feed.image,
    };
  } catch (error) {
    console.error(`Error fetching feed ${url}:`, error);
    throw new Error(`Failed to fetch feed: ${(error as Error).message}`);
  }
}

/**
 * Parses an OPML string and extracts feeds and folders
 */
export function parseOPML(xmlContent: string): OpmlOutline[] {
  try {
    const xmlParser = new XMLParser({
        ignoreAttributes: false,
        attributeNamePrefix: "",
    });
    const parsed = xmlParser.parse(xmlContent);

    if (!parsed.opml || !parsed.opml.body) {
        throw new Error("Invalid OPML format");
    }

    const body = parsed.opml.body;
    let outlines = body.outline;

    // Normalize to array
    if (!Array.isArray(outlines)) {
        outlines = [outlines];
    }

    return normalizeOutlines(outlines);
  } catch (error) {
    console.error('Error parsing OPML:', error);
    throw new Error('Failed to parse OPML content');
  }
}

function normalizeOutlines(outlines: any[]): OpmlOutline[] {
    return outlines.map(outline => {
        const result: OpmlOutline = {
            text: outline.text,
            title: outline.title || outline.text,
            type: outline.type,
            xmlUrl: outline.xmlUrl,
            htmlUrl: outline.htmlUrl,
        };

        if (outline.outline) {
             let children = outline.outline;
             if (!Array.isArray(children)) {
                 children = [children];
             }
             result.outlines = normalizeOutlines(children);
        }

        return result;
    });
}
