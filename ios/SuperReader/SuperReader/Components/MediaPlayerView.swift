import SwiftUI
import WebKit

struct MediaPlayerView: View {
    let videoUrl: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                // Close Button Header
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                
                Spacer()
                
                // Video Player
                VideoWebView(urlStr: videoUrl)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16/9, contentMode: .fit)
                
                Spacer()
            }
        }
    }
}

struct VideoWebView: UIViewRepresentable {
    let urlStr: String
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .black
        webView.isOpaque = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        var finalUrl = urlStr
        
        // Convert YouTube watch URL to embed URL if needed
        if urlStr.contains("youtube.com/watch") || urlStr.contains("youtu.be/") {
            finalUrl = urlStr
                .replacingOccurrences(of: "watch?v=", with: "embed/")
                .replacingOccurrences(of: "youtu.be/", with: "www.youtube.com/embed/")
            
            // Append autoplay and other params if not present
            if !finalUrl.contains("?") {
                finalUrl += "?autoplay=1&playsinline=1"
            } else {
                finalUrl += "&autoplay=1&playsinline=1"
            }
        }
        
        if let url = URL(string: finalUrl) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}

#Preview {
    MediaPlayerView(videoUrl: "https://www.youtube.com/embed/dQw4w9WgXcQ")
}
