import Parser from 'rss-parser';
import { XMLParser } from 'fast-xml-parser';

export interface FeedItem {
  title?: string;
  link?: string;
  pubDate?: string;
  author?: string;
  content?: string;
  contentSnippet?: string;
  isoDate?: string;
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
    ],
  },
});

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
