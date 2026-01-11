import SwiftUI
import WebKit

struct HTMLContentView: UIViewRepresentable {
    let htmlContent: String
    let preferences: ReadingPreferences
    @Binding var dynamicHeight: CGFloat
    var onLinkTap: ((URL) -> Void)? = nil
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Disable data detectors to prevent unwanted links (phone numbers etc) unless they are actual links
        config.dataDetectorTypes = [.link]
        
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
        
        // Only reload if content or relevant preferences changed
        // For simplicity in this implementation, we load HTML. 
        // In a more optimized version, we might inject JS to change styles without full reload.
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
        // We need a way to get hex strings from SwiftUI Color. 
        // For now, let's map the theme enum directly to known hex values or use a helper.
        // Since we don't have easy access to hex from SwiftUI Color in standard library without extensions,
        // we'll use a mapping based on the ColorTheme enum.
        
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
                
                body {
                    font-family: \(fontFamily);
                    font-size: \(fontSize)px;
                    line-height: \(lineHeight);
                    color: \(textColor);
                    background-color: transparent; /* Let SwiftUI background show */
                    margin: 0;
                    padding: 0; /* Padding is handled by SwiftUI container */
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
                    margin-left: 0;
                    padding-left: 15px;
                    border-left: 4px solid \(linkColor);
                    opacity: 0.8;
                    font-style: italic;
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
            return "'SF Mono', Menlo, Monaco, monospace"
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: HTMLContentView
        
        init(_ parent: HTMLContentView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Calculate height
            webView.evaluateJavaScript("document.body.scrollHeight") { (result, error) in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        // Avoid update cycles by checking difference
                        if abs(self.parent.dynamicHeight - height) > 1 {
                            self.parent.dynamicHeight = height
                        }
                    }
                }
            }
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
