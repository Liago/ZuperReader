import SwiftUI
import WebKit

/// Helpers to recognise and normalise video embed URLs found in parsed articles.
enum VideoEmbed {
    /// Origin we identify ourselves with when embedding third-party players.
    /// YouTube refuses to play embeds that arrive without a Referer / HTTP origin
    /// ("Video player configuration error", Error 153), which is exactly what a
    /// WKWebView loading the embed URL directly sends.
    static let embedOrigin = SupabaseConfig.publicWebUrl

    /// Turns protocol-relative (`//host/...`) or entity-encoded URLs into a loadable URL string.
    static func normalized(_ raw: String) -> String {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#038;", with: "&")
        if url.hasPrefix("//") { url = "https:" + url }
        return url
    }

    /// Extracts the 11-character YouTube video id from any common YouTube URL form
    /// (watch, youtu.be, embed, youtube-nocookie, shorts, live, v/).
    static func youTubeId(from raw: String) -> String? {
        let url = normalized(raw)
        guard url.range(of: "youtube.com|youtu.be|youtube-nocookie.com", options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        let pattern = "(?:youtu\\.be/|/embed/|/shorts/|/live/|/v/|[?&]v=)([A-Za-z0-9_-]{11})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = url as NSString
        guard let match = regex.firstMatch(in: url, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    /// Public watch page, used for "Open in YouTube".
    static func youTubeWatchURL(id: String) -> URL? {
        URL(string: "https://www.youtube.com/watch?v=\(id)")
    }
}

struct MediaPlayerView: View {
    let videoUrl: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL

    private var youTubeId: String? { VideoEmbed.youTubeId(from: videoUrl) }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack {
                // Close Button Header
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(Typography.symbol(18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Close")
                    .padding()
                }

                Spacer()

                // Video Player
                VideoWebView(urlStr: videoUrl)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)

                // Fallback: some videos disable embedding altogether.
                if let id = youTubeId, let watchURL = VideoEmbed.youTubeWatchURL(id: id) {
                    Button {
                        openURL(watchURL)
                    } label: {
                        Label("Open in YouTube", systemImage: "arrow.up.right.square")
                            .font(Typography.symbol(14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 16)
                }

                Spacer()
            }
        }
    }
}

struct VideoWebView: UIViewRepresentable {
    let urlStr: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.uiDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only (re)load when the URL actually changes: SwiftUI calls this on
        // every state update, and reloading restarts the video.
        guard context.coordinator.loadedUrl != urlStr else { return }
        context.coordinator.loadedUrl = urlStr

        let originURL = URL(string: VideoEmbed.embedOrigin)

        if let id = VideoEmbed.youTubeId(from: urlStr) {
            // Host the player in a page served "from" our web origin so the embed
            // request carries a valid Referer/origin (fixes YouTube Error 153).
            let origin = VideoEmbed.embedOrigin.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            let src = "https://www.youtube.com/embed/\(id)?playsinline=1&autoplay=1&rel=0&modestbranding=1&enablejsapi=1&origin=\(origin)"
            webView.loadHTMLString(Self.playerPage(iframeSrc: src), baseURL: originURL)
            return
        }

        let normalized = VideoEmbed.normalized(urlStr)
        guard let url = URL(string: normalized) else { return }

        if url.pathExtension.lowercased() == "mp4" || url.pathExtension.lowercased() == "m3u8" || url.pathExtension.lowercased() == "mov" {
            webView.loadHTMLString(Self.videoPage(src: normalized), baseURL: originURL)
        } else {
            // Other embeds (Vimeo, Dailymotion, …) also tend to require a Referer.
            var request = URLRequest(url: url)
            request.setValue(VideoEmbed.embedOrigin + "/", forHTTPHeaderField: "Referer")
            webView.load(request)
        }
    }

    private static func escapeAttribute(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
    }

    private static let pageStyle = """
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <style>
      html, body { margin: 0; padding: 0; height: 100%; background: #000; overflow: hidden; }
      iframe, video { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
    </style>
    """

    private static func playerPage(iframeSrc: String) -> String {
        """
        <!DOCTYPE html>
        <html><head>\(pageStyle)
        <meta name="referrer" content="strict-origin-when-cross-origin">
        </head><body>
        <iframe src="\(escapeAttribute(iframeSrc))"
                referrerpolicy="strict-origin-when-cross-origin"
                allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
                allowfullscreen></iframe>
        </body></html>
        """
    }

    private static func videoPage(src: String) -> String {
        """
        <!DOCTYPE html>
        <html><head>\(pageStyle)</head><body>
        <video src="\(escapeAttribute(src))" controls autoplay playsinline></video>
        </body></html>
        """
    }

    final class Coordinator: NSObject, WKUIDelegate {
        var loadedUrl: String?

        // Links that try to open a new window (e.g. "Watch on YouTube" inside the
        // player) go to the system so the YouTube app / Safari can handle them.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
            return nil
        }
    }
}

#Preview {
    MediaPlayerView(videoUrl: "https://www.youtube.com/embed/dQw4w9WgXcQ")
}
