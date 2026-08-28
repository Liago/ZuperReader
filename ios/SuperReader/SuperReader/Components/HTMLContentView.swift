import SwiftUI
import WebKit

struct HTMLContentView: UIViewRepresentable {
    let htmlContent: String
    let preferences: ReadingPreferences
    @Binding var dynamicHeight: CGFloat
    var onLinkTap: ((URL) -> Void)? = nil
    var onImageTap: ((String, Int) -> Void)? = nil  // URL and index
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Disable data detectors to prevent unwanted links (phone numbers etc) unless they are actual links
        config.dataDetectorTypes = [.link]

        // Register script message handlers
        config.userContentController.add(context.coordinator, name: "heightObserver")
        config.userContentController.add(context.coordinator, name: "imageTapHandler")

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
                    font-family: 'Figtree';
                    src: url('Figtree-Regular.ttf') format('truetype');
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
                    padding-left: 15px;
                    border-left: 4px solid \(linkColor);
                    opacity: 0.8;
                    font-style: italic;
                }
                
                /* Modern Image Card Styles - Matching Web Version */
                figure, .wp-caption, div[id^="attachment_"], .wp-block-image {
                    border-radius: 12px !important;
                    overflow: hidden !important;
                    border: 1px solid \(preferences.colorTheme == .dark ? "rgb(51, 65, 85)" : "#E5E7EB") !important; /* slate-700 / gray-200 */
                    background-color: \(preferences.colorTheme == .dark ? "rgb(30, 41, 59)" : "#ffffff") !important; /* slate-800 / white */
                    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05) !important; /* shadow-lg */
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
                    color: \(preferences.colorTheme == .dark ? "rgb(209, 213, 219)" : "#4B5563") !important; /* gray-300 / gray-600 */
                    background-color: \(preferences.colorTheme == .dark ? "rgba(30, 41, 59, 0.5)" : "rgb(249, 250, 251)") !important; /* slate-800/50 / gray-50 */
                    border-top: 1px solid \(preferences.colorTheme == .dark ? "rgba(51, 65, 85, 0.5)" : "#F3F4F6") !important; /* slate-700/50 / gray-100 */
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
            </script>
        </body>
        </html>
        """
    }
    
    private func getThemeColors(theme: ColorTheme) -> (text: String, link: String) {
        switch theme {
        case .cream, .system:
            return ("#201E1D", "#C67139") // text, accent
        case .sepia:
            return ("#3A2F1F", "#C67139")
        case .dark:
            return ("#F3EBDF", "#E2975F")
        }
    }

    private func getCSSFontFamily(for family: Typography.FontFamily) -> String {
        switch family {
        case .lora:
            return "'Lora', Georgia, serif"
        case .figtree:
            return "'Figtree', -apple-system, sans-serif"
        case .mono:
            return "'SF Mono', Menlo, Monaco, monospace"
        }
    }
    
    // Helper function to extract image URLs from HTML
    static func extractImageUrls(from html: String) -> [String] {
        var imageUrls: [String] = []

        // Simple regex pattern to find img src attributes
        let pattern = "<img[^>]+src=\"([^\"]+)\""
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
