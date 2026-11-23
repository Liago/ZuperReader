import SwiftUI
import WebKit

struct HTMLContentView: UIViewRepresentable {
    let htmlContent: String
    let preferences: ReadingPreferences
    @Binding var dynamicHeight: CGFloat
    var onLinkTap: ((URL) -> Void)? = nil
    var onImageTap: ((String, Int) -> Void)? = nil  // URL and index
    var onBodyTap: (() -> Void)? = nil  // Any tap that isn't on a link or image (Focus mode chrome toggle)

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Disable data detectors to prevent unwanted links (phone numbers etc) unless they are actual links
        config.dataDetectorTypes = [.link]

        // Register script message handlers
        config.userContentController.add(context.coordinator, name: "heightObserver")
        config.userContentController.add(context.coordinator, name: "imageTapHandler")
        config.userContentController.add(context.coordinator, name: "bodyTapHandler")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = .clear
        webView.isOpaque = false // Important for background color to show through

        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Construct the full HTML with CSS based on preferences
        let fullHtml = generateHtml(content: htmlContent, preferences: preferences)
        
        // Check if we need to reload (avoid reload if content matches current)
        // For now, simple reload is safer to ensure preferences stick
        webView.loadHTMLString(fullHtml, baseURL: Bundle.main.bundleURL)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func generateHtml(content: String, preferences: ReadingPreferences) -> String {
        let fontFamily = getCSSFontFamily(for: preferences.fontFamily)
        let fontSize = Int(preferences.fontSize)
        // Map ColorTheme to CSS values
        let (textColor, linkColor) = getThemeColors(theme: preferences.colorTheme)
        
        // Line height multiplier
        let lineHeight = preferences.lineHeight.multiplier
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                @font-face {
                    font-family: 'Lora';
                    src: url('Lora-Regular.ttf') format('truetype');
                }
                @font-face {
                    font-family: 'Literata';
                    src: url('Literata-Regular.ttf') format('truetype');
                    font-weight: 400;
                }
                @font-face {
                    font-family: 'Literata';
                    src: url('Literata-Bold.ttf') format('truetype');
                    font-weight: 700;
                }
                @font-face {
                    font-family: 'Merriweather';
                    src: url('Merriweather-Regular.ttf') format('truetype');
                    font-weight: 400;
                }
                @font-face {
                    font-family: 'Merriweather';
                    src: url('Merriweather-Bold.ttf') format('truetype');
                    font-weight: 700;
                }
                @font-face {
                    font-family: 'Figtree';
                    src: url('Figtree-Regular.ttf') format('truetype');
                    font-weight: 400;
                }
                @font-face {
                    font-family: 'Figtree';
                    src: url('Figtree-Bold.ttf') format('truetype');
                    font-weight: 700;
                }
                @font-face {
                    font-family: 'Atkinson Hyperlegible';
                    src: url('AtkinsonHyperlegible-Regular.ttf') format('truetype');
                    font-weight: 400;
                }
                @font-face {
                    font-family: 'Atkinson Hyperlegible';
                    src: url('AtkinsonHyperlegible-Bold.ttf') format('truetype');
                    font-weight: 700;
                }
                @font-face {
                    font-family: 'Nunito';
                    src: url('Nunito-Regular.ttf') format('truetype');
                    font-weight: 400;
                }
                @font-face {
                    font-family: 'Nunito';
                    src: url('Nunito-Bold.ttf') format('truetype');
                    font-weight: 700;
                }

                body {
                    font-family: \(fontFamily);
                    font-size: \(fontSize)px;
                    line-height: \(lineHeight);
                    color: \(textColor);
                    background-color: transparent; /* Let SwiftUI background show */
                    margin: 0;
                    padding: 0 0 40px 0; /* Add bottom padding to prevent clipping */
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
                a {
                    color: \(linkColor);
                    text-decoration: none;
                    border-bottom: 1px solid \(linkColor);
                }
                img, video, iframe {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    margin: 10px 0;
                    cursor: pointer;
                }
                img:active {
                    opacity: 0.8;
                }
                p {
                    margin-bottom: 1em;
                }
                /* Additional typography tweaks */
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 1.5em;
                    margin-bottom: 0.5em;
                    line-height: 1.3;
                    font-weight: 700;
                }
                ul, ol {
                    padding-left: 20px;
                    margin-bottom: 1em;
                }
                blockquote {
                    padding-left: 15px;
                    border-left: 4px solid \(linkColor);
                    opacity: 0.8;
                    font-style: italic;
                }
                
                /* Modern Image Card Styles - Matching Web Version */
                figure, .wp-caption, div[id^="attachment_"], .wp-block-image {
                    border-radius: 12px !important;
                    overflow: hidden !important;
                    border: 1px solid \(preferences.colorTheme == .dark ? "#2A3133" : "#E3E6E7") !important; /* line */
                    background-color: \(preferences.colorTheme == .dark ? "#1B2022" : "#FFFFFF") !important; /* card */
                    box-shadow: none !important; /* Editorial Teal: border, no shadow */
                    margin: 24px auto !important;
                    page-break-inside: avoid !important;
                    max-width: 100% !important;
                    display: block !important;
                }
                
                figure img, .wp-caption img, div[id^="attachment_"] img, .wp-block-image img {
                    width: 100% !important;
                    height: auto !important;
                    margin: 0 !important;
                    padding: 0 !important;
                    display: block !important;
                    border-radius: 0 !important; /* Reset border radius as the container has it */
                }
                
                figcaption, .wp-caption-text, div[id^="attachment_"] > p, .wp-block-image figcaption {
                    padding: 16px !important;
                    font-size: 0.9em !important;
                    text-align: center !important;
                    font-weight: 500 !important;
                    color: \(preferences.colorTheme == .dark ? "#9AA3A5" : "#5F6668") !important; /* muted */
                    background-color: \(preferences.colorTheme == .dark ? "#151A1B" : "#F7F8F8") !important; /* rail */
                    border-top: 1px solid \(preferences.colorTheme == .dark ? "#2A3133" : "#EEF0F0") !important; /* line */
                    margin: 0 !important;
                    font-family: \(fontFamily) !important;
                    line-height: 1.6 !important;
                }
                
                /* Specific fix for the user's screenshot structure where explicit height/width might interfere */
                div[id^="attachment_"] {
                   width: auto !important; 
                   height: auto !important;
                }

                pre, code {
                    font-family: "SF Mono", Menlo, monospace;
                    background-color: rgba(128, 128, 128, 0.1);
                    padding: 2px 4px;
                    border-radius: 4px;
                    font-size: 0.9em;
                }
                pre {
                    padding: 10px;
                    overflow-x: auto;
                }
            </style>
        </head>
        <body>
            \(content)
            <script>
                // Make all images clickable and track their index
                document.addEventListener('DOMContentLoaded', function() {
                    const images = document.querySelectorAll('img');
                    images.forEach((img, index) => {
                        img.addEventListener('click', function(e) {
                            e.preventDefault();
                            window.webkit.messageHandlers.imageTapHandler.postMessage({
                                url: img.src,
                                index: index
                            });
                        });
                    });
                });

                // Any tap that isn't on a link or image restores the reader
                // chrome when Focus mode is active (docs/revamp-ios/README.md · "04 Focus").
                document.body.addEventListener('click', function(e) {
                    if (e.target.closest('a') || e.target.closest('img')) return;
                    window.webkit.messageHandlers.bodyTapHandler.postMessage({});
                });
            </script>
        </body>
        </html>
        """
    }
    
    private func getThemeColors(theme: ColorTheme) -> (text: String, link: String) {
        switch theme {
        // Reader body ink is a touch softer than UI text (#24292B vs
        // #16191A) for long-form reading; links use the theme accent.
        case .cream, .system:
            return ("#24292B", "#33666C") // text, accent
        case .sepia:
            return ("#3B3226", "#2F5F65")
        case .dark:
            return ("#E3E8E8", "#7FB3B9")
        }
    }

    private func getCSSFontFamily(for family: Typography.FontFamily) -> String {
        switch family {
        case .lora:
            return "'Lora', Georgia, serif"
        case .literata:
            return "'Literata', Georgia, serif"
        case .merriweather:
            return "'Merriweather', Georgia, serif"
        case .figtree:
            return "'Figtree', -apple-system, sans-serif"
        case .atkinson:
            return "'Atkinson Hyperlegible', -apple-system, sans-serif"
        case .nunito:
            return "'Nunito', -apple-system, sans-serif"
        case .mono:
            return "'SF Mono', Menlo, Monaco, monospace"
        }
    }
    
    // Helper function to extract image URLs from HTML
    static func extractImageUrls(from html: String) -> [String] {
        var imageUrls: [String] = []

        // Simple regex pattern to find img src attributes
        let pattern = "<img\\b[^>]*?\\ssrc\\s*=\\s*[\"']([^\"']+)[\"']"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let nsString = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches {
                if match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    let url = nsString.substring(with: range)
                    imageUrls.append(url)
                }
            }
        }

        return imageUrls
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: HTMLContentView
        
        init(_ parent: HTMLContentView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightObserver", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    // Update dynamicHeight binding
                    if abs(self.parent.dynamicHeight - height) > 1 {
                        self.parent.dynamicHeight = height
                    }
                }
            } else if message.name == "imageTapHandler", let body = message.body as? [String: Any],
                      let url = body["url"] as? String,
                      let index = body["index"] as? Int {
                DispatchQueue.main.async {
                    self.parent.onImageTap?(url, index)
                }
            } else if message.name == "bodyTapHandler" {
                DispatchQueue.main.async {
                    self.parent.onBodyTap?()
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Inject ResizeObserver to monitor height changes
            let js = """
            const resizeObserver = new ResizeObserver(entries => {
                window.webkit.messageHandlers.heightObserver.postMessage(document.body.scrollHeight);
            });
            resizeObserver.observe(document.body);
            // Initial check
            window.webkit.messageHandlers.heightObserver.postMessage(document.body.scrollHeight);
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
        
        // Handle links - open in external browser or handle navigation
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url {
                    if let onLinkTap = self.parent.onLinkTap {
                        onLinkTap(url)
                    } else {
                        // Fallback
                        UIApplication.shared.open(url)
                    }
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
    

}
