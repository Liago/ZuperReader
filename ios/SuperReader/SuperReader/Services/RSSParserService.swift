import Foundation

struct ParsedRSSItem {
    var title: String = ""
    var link: String = ""
    var guid: String = ""
    var pubDate: Date?
    var content: String = ""
    var contentSnippet: String = ""
    var imageUrl: String?
    var author: String = ""
}

class RSSParserService {
    static let shared = RSSParserService()
    
    // We strictly use this service as a factory/entry point. 
    // It does not hold state itself.
    
    func parse(data: Data) async -> [ParsedRSSItem] {
        let parser = FeedParser(data: data)
        return await parser.parse()
    }
}

// Private helper class that handles a SINGLE parsing job
private class FeedParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var completion: (([ParsedRSSItem]) -> Void)?
    private var currentItems: [ParsedRSSItem] = []
    private var currentItem: ParsedRSSItem?
    private var currentElement: String = ""
    private var currentCharacters: String = ""
    private var currentAttributes: [String : String] = [:]
    
    init(data: Data) {
        self.data = data
    }
    
    func parse() async -> [ParsedRSSItem] {
        return await withCheckedContinuation { continuation in
            self.startParsing { items in
                continuation.resume(returning: items)
            }
        }
    }
    
    private func startParsing(completion: @escaping ([ParsedRSSItem]) -> Void) {
        self.completion = completion
        self.currentItems = []
        
        print("RSSParserService: Starting parse for data of size \(data.count) bytes")
        
        // Robust Encoding Handling
        var parserData = data
        
        // 1. Try to detect if it's valid UTF-8
        let utf8String = String(data: data, encoding: .utf8)
        
        if utf8String == nil {
            print("RSSParserService: Data is NOT valid UTF-8. Attempting fallback decoding.")
            // 2. Fallback to ISO-8859-1 (Latin1)
            if let latin1String = String(data: data, encoding: .isoLatin1) {
                // Convert to UTF-8 data
                // We also need to replace the encoding declaration if it exists, to match the new UTF-8 data
                var fixedString = latin1String.replacingOccurrences(of: "encoding=\"ISO-8859-1\"", with: "encoding=\"UTF-8\"", options: .caseInsensitive)
                fixedString = fixedString.replacingOccurrences(of: "encoding='ISO-8859-1'", with: "encoding='UTF-8'", options: .caseInsensitive)
                
                if let utf8Data = fixedString.data(using: .utf8) {
                    parserData = utf8Data
                }
            } else if let windowsString = String(data: data, encoding: .windowsCP1252) {
                 // Fallback to Windows-1252
                 if let utf8Data = windowsString.data(using: .utf8) {
                     parserData = utf8Data
                 }
            }
        }
        
        let parser = XMLParser(data: parserData)
        parser.delegate = self
        let success = parser.parse()
        if !success {
            print("RSSParserService: XMLParser.parse() returned false. Error: \(parser.parserError?.localizedDescription ?? "Unknown error")")
        } else {
             print("RSSParserService: Parse successful. Found \(currentItems.count) items.")
        }
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentAttributes = attributeDict
        currentCharacters = ""
        
        if elementName == "item" || elementName == "entry" { // RSS item or Atom entry
            currentItem = ParsedRSSItem()
        }
        
        if let _ = currentItem {
            // Image extraction from enclosure or media:content
            if elementName == "enclosure" {
                if let type = attributeDict["type"], type.hasPrefix("image/"), let url = attributeDict["url"] {
                    currentItem?.imageUrl = url
                }
            } else if elementName == "media:content" {
                if let type = attributeDict["type"], type.hasPrefix("image/"), let url = attributeDict["url"] {
                     currentItem?.imageUrl = url
                } else if let medium = attributeDict["medium"], medium == "image", let url = attributeDict["url"] {
                    currentItem?.imageUrl = url
                }
            } else if elementName == "media:thumbnail" {
                 if let url = attributeDict["url"] {
                     currentItem?.imageUrl = url
                 }
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentCharacters += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if let _ = currentItem {
            switch elementName {
            case "item", "entry":
                if let item = currentItem {
                    var finalItem = item
                    // Post-processing
                    if finalItem.guid.isEmpty {
                        finalItem.guid = finalItem.link // Fallback guid
                    }
                    if finalItem.content.isEmpty && !finalItem.contentSnippet.isEmpty {
                        finalItem.content = finalItem.contentSnippet
                    }
                    // Extract image from content if missing
                    if finalItem.imageUrl == nil {
                        finalItem.imageUrl = extractImageFromHTML(finalItem.content)
                    }
                    // Generate snippet if missing
                    if finalItem.contentSnippet.isEmpty {
                        finalItem.contentSnippet = finalItem.content.strippingHTML().prefix(300).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    currentItems.append(finalItem)
                }
                currentItem = nil
                
            case "title":
                currentItem?.title = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
            case "link":
                 // Atom uses href attribute
                if let href = currentAttributes["href"] {
                     currentItem?.link = href
                } else {
                     currentItem?.link = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            case "guid", "id":
                currentItem?.guid = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
            case "pubDate", "dc:date", "published", "updated":
                let dateStr = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
                currentItem?.pubDate = Date.fromRSSString(dateStr)
            case "description":
                let text = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
                currentItem?.contentSnippet = text
                if currentItem?.content.isEmpty == true {
                     currentItem?.content = text
                }
            case "content:encoded", "content":
                currentItem?.content = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
            case "dc:creator", "author", "name": // Atom uses name inside author
                currentItem?.author = currentCharacters.trimmingCharacters(in: .whitespacesAndNewlines)
            default:
                break
            }
        }
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        completion?(currentItems)
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("XML Parse Error: \(parseError.localizedDescription)")
        completion?([])
    }
    
    // MARK: - Helpers
    
    private func extractImageFromHTML(_ html: String) -> String? {
        // Simple regex to find the first img src
        let pattern = "<img[^>]+src=[\"']([^\"']+)[\"']"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: html.utf16.count)
            if let match = regex.firstMatch(in: html, options: [], range: range) {
                if let range = Range(match.range(at: 1), in: html) {
                    return String(html[range])
                }
            }
        }
        return nil
    }
}

extension Date {
    /// Parse a date string from an RSS/Atom feed, tolerating the many formats feeds use in the wild:
    /// RFC-822 with numeric offset (`+0000`), RFC-822 with a named timezone (`PDT`, `EST`, ...),
    /// ISO-8601 with and without fractional seconds, and RFC-822 without seconds.
    static func fromRSSString(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        for formatter in Self.rssDateFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        // ISO-8601 fallbacks (handle both with and without fractional seconds).
        if let date = Self.iso8601WithFractional.date(from: trimmed) { return date }
        if let date = Self.iso8601Plain.date(from: trimmed) { return date }
        return nil
    }

    private static let rssDateFormatters: [DateFormatter] = {
        // `Z` matches numeric offsets/GMT; `zzz` matches named abbreviations like PDT/EST.
        let patterns = [
            "E, d MMM yyyy HH:mm:ss Z",     // RFC-822, numeric offset
            "E, d MMM yyyy HH:mm:ss zzz",   // RFC-822, named timezone (PDT, EST, ...)
            "E, d MMM yyyy HH:mm Z",        // RFC-822, no seconds, numeric offset
            "E, d MMM yyyy HH:mm zzz",      // RFC-822, no seconds, named timezone
            "yyyy-MM-dd'T'HH:mm:ssZ",       // ISO-8601 basic
            "yyyy-MM-dd HH:mm:ss",          // occasional non-standard variant
        ]
        return patterns.map { pattern in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = pattern
            return formatter
        }
    }()

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Plain = ISO8601DateFormatter()
}


