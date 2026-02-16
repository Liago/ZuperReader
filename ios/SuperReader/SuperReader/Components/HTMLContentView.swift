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
        // Convert ColorTheme to CSS hex colors
        let colors = preferences.colorTheme.colors
        
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
                    font-family: 'Inter';
                    src: url('Inter-Regular.ttf') format('truetype');
                }
                @font-face {
                    font-family: 'Poppins';
                    src: url('Poppins-Regular.ttf') format('truetype');
                }
                @font-face {
                    font-family: 'Lora';
                    src: url('Lora-Regular.ttf') format('truetype');
                }
                @font-face {
                    font-family: 'Montserrat';
                    src: url('Montserrat-Regular.ttf') format('truetype');
                }
                @font-face {
                    font-family: 'Crimson Text';
                    src: url('CrimsonText-Regular.ttf') format('truetype');
                }
                @font-face {
                    font-family: 'Lato';
                    src: url('Lato-Regular.ttf') format('truetype');
                }
                @font-face {
                    font-family: 'Roboto';
                    src: url('Roboto-Regular.ttf') format('truetype');
                }
                @font-face {
                    font-family: 'Open Sans';
                    src: url('OpenSans-Regular.ttf') format('truetype');
                }
                @font-face {
                    font-family: 'Ubuntu';
                    src: url('Ubuntu-Regular.ttf') format('truetype');
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
                
                /* Modern Image Card Styles */
                figure, .wp-caption, div[id^="attachment_"] {
                    border-radius: 12px;
                    overflow: hidden;
                    border: 1px solid \(preferences.colorTheme == .dark ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.1)");
                    background-color: \(preferences.colorTheme == .dark ? "rgba(30, 41, 59, 0.5)" : "rgba(255, 255, 255, 0.8)");
                    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
                    margin: 2em 0;
                    page-break-inside: avoid;
                }
                
                figure img, .wp-caption img, div[id^="attachment_"] img {
                    width: 100%;
                    height: auto;
                    margin: 0;
                    padding: 0;
                    display: block;
                    border-radius: 0; /* Reset border radius as the container has it */
                }
                
                figcaption, .wp-caption-text, div[id^="attachment_"] > p {
                    padding: 12px 16px;
                    font-size: 0.9em;
                    text-align: center;
                    color: \(textColor);
                    opacity: 0.8;
                    background-color: \(preferences.colorTheme == .dark ? "rgba(0,0,0,0.2)" : "rgba(0,0,0,0.02)");
                    border-top: 1px solid \(preferences.colorTheme == .dark ? "rgba(255,255,255,0.05)" : "rgba(0,0,0,0.05)");
                    margin: 0;
                    font-family: \(fontFamily); /* Ensure caption matches font */
                }
                
                /* Adjust prose default overrides */
                div[id^="attachment_"] {
                   width: auto !important; 
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
        case .light:
            return ("#111827", "#9333EA") // textPrimary, accent
        case .dark:
            return ("#F1F5F9", "#818CF8")
        case .ocean:
            return ("#164E63", "#0891B2")
        case .forest:
            return ("#14532D", "#16A34A")
        case .sunset:
            return ("#581C87", "#A855F7")
        }
    }
    
    private func getCSSFontFamily(for family: Typography.FontFamily) -> String {
        switch family {
        case .sans:
            return "-apple-system, system-ui, 'Helvetica Neue', sans-serif"
        case .serif:
            return "Georgia, 'Times New Roman', Times, serif"
        case .mono:
            return "'SF Mono', Menlo, Monaco, monospace"
        case .inter:
            return "'Inter', -apple-system, sans-serif"
        case .poppins:
            return "'Poppins', sans-serif"
        case .lora:
            return "'Lora', Georgia, serif"
        case .montserrat:
            return "'Montserrat', sans-serif"
        case .crimsonText:
            return "'Crimson Text', Georgia, serif"
        case .lato:
            return "'Lato', sans-serif"
        case .roboto:
            return "'Roboto', -apple-system, sans-serif"
        case .openSans:
            return "'Open Sans', sans-serif"
        case .ubuntu:
            return "'Ubuntu', sans-serif"
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
