import SwiftUI

// MARK: - Feed image store
//
// `rss_feeds` stores no image, so the app resolves one per feed on device:
//  1. the feed's own image — RSS `<channel><image><url>`, `<itunes:image href>`,
//     Atom `<logo>` / `<icon>` — read from the top of the feed XML;
//  2. otherwise the site's icon (Google favicon service, 128px, which serves
//     the apple-touch-icon when the site has one — same source as the web).
// Results are cached in UserDefaults so each feed is resolved only once.

@MainActor
final class FeedImageStore: ObservableObject {
    static let shared = FeedImageStore()

    @Published private(set) var urls: [UUID: String] = [:]

    private var inFlight: Set<UUID> = []
    private let defaultsKey = "feedImageURLs.v1"

    private init() {
        let stored = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
        var restored: [UUID: String] = [:]
        for (key, value) in stored {
            if let id = UUID(uuidString: key) { restored[id] = value }
        }
        urls = restored
    }

    func imageURL(for feed: RSSFeed) -> String? {
        urls[feed.id]
    }

    func resolve(_ feed: RSSFeed) {
        guard urls[feed.id] == nil, !inFlight.contains(feed.id) else { return }
        inFlight.insert(feed.id)

        let feedURL = feed.url
        let siteURL = feed.siteUrl
        Task {
            let channelImage = await Self.fetchChannelImage(feedURL: feedURL)
            let resolved = channelImage ?? Self.faviconURL(siteURL: siteURL, feedURL: feedURL)
            inFlight.remove(feed.id)
            guard let resolved else { return }
            urls[feed.id] = resolved
            persist()
        }
    }

    private func persist() {
        let dictionary = Dictionary(uniqueKeysWithValues: urls.map { ($0.key.uuidString, $0.value) })
        UserDefaults.standard.set(dictionary, forKey: defaultsKey)
    }

    // MARK: - Resolution

    private static func faviconURL(siteURL: String?, feedURL: String) -> String? {
        let host = URL(string: siteURL ?? "")?.host ?? URL(string: feedURL)?.host
        guard let host, !host.isEmpty else { return nil }
        return "https://www.google.com/s2/favicons?domain=\(host)&sz=128"
    }

    private static func fetchChannelImage(feedURL: String) async -> String? {
        guard let url = URL(string: feedURL) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("ZuperReader/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        guard let result = try? await URLSession.shared.data(for: request),
              let http = result.1 as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { return nil }

        let delegate = ChannelImageParser()
        let parser = XMLParser(data: result.0)
        parser.shouldProcessNamespaces = false
        parser.delegate = delegate
        parser.parse()

        guard let raw = delegate.result?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let absolute = URL(string: raw, relativeTo: url)?.absoluteURL,
              absolute.scheme?.hasPrefix("http") == true else { return nil }
        return absolute.absoluteString
    }
}

/// Reads the channel-level image of an RSS / Atom feed and stops at the
/// first item, so only the head of the document is parsed.
private final class ChannelImageParser: NSObject, XMLParserDelegate {
    private var path: [String] = []
    private var text = ""
    private var rssImage: String?
    private var itunesImage: String?
    private var atomLogo: String?
    private var atomIcon: String?

    var result: String? { rssImage ?? itunesImage ?? atomLogo ?? atomIcon }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "item" || elementName == "entry" {
            parser.abortParsing()
            return
        }
        if elementName == "itunes:image", itunesImage == nil, let href = attributeDict["href"] {
            itunesImage = href
        }
        path.append(elementName)
        text = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = path.dropLast().last

        if !value.isEmpty {
            if elementName == "url", parent == "image", rssImage == nil {
                rssImage = value
            } else if elementName == "logo", parent == "feed", atomLogo == nil {
                atomLogo = value
            } else if elementName == "icon", parent == "feed", atomIcon == nil {
                atomIcon = value
            }
        }

        if !path.isEmpty { path.removeLast() }
        text = ""
    }
}

// MARK: - Feed avatar

/// Circular feed avatar: the feed image fills the circle as a cover; the
/// monogram shows while it loads or when there is no image.
struct FeedAvatar: View {
    let feed: RSSFeed
    let size: CGFloat
    var monogramFont: Font? = nil

    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var store = FeedImageStore.shared

    var body: some View {
        ZStack {
            Circle().fill(themeManager.colors.page)

            Text(FeedSourceBubble.monogram(for: feed.title))
                .font(monogramFont ?? Typography.ui(size * 0.27, weight: .bold))
                .foregroundColor(themeManager.colors.text)

            if let urlString = store.imageURL(for: feed), let url = URL(string: urlString) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .background(Color.white)
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(themeManager.colors.line, lineWidth: 1))
        .onAppear { store.resolve(feed) }
        .accessibilityHidden(true)
    }
}
