import SwiftUI

struct VideoPreviewView: View {
    let videoUrl: String
    let onPlay: () -> Void
    var title: String = "Riproduci Video"
    
    @State private var thumbnailUrl: URL?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onPlay) {
            ZStack {
                // Background / Thumbnail
                if let url = thumbnailUrl {
                    AsyncImageView(url: url.absoluteString, cornerRadius: 16)
                        .overlay(Color.black.opacity(0.2))
                } else {
                    // Fallback gradient
                    LinearGradient(
                        colors: [
                            Color.indigo.opacity(0.1),
                            Color.purple.opacity(0.1),
                            Color.pink.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        Image(systemName: "video.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.indigo.opacity(0.3))
                    )
                }
                
                // Overlay Gradient
                Color.black.opacity(0.2)
                
                // Play Button
                Circle()
                    .fill(colorScheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.9))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(colorScheme == .dark ? .white : .indigo)
                            .offset(x: 2) // Visual correction
                    )
                    .shadow(radius: 10)
                
                // Title Label
                VStack {
                    Spacer()
                    HStack {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Material.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .buttonStyle(PlainButtonStyle()) // Prevent default button styling
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.vertical, 8)
        .onAppear {
            extractThumbnail()
        }
    }
    
    private func extractThumbnail() {
        // Extract YouTube thumbnail if possible
        if let ytId = getYouTubeId(from: videoUrl) {
            thumbnailUrl = URL(string: "https://img.youtube.com/vi/\(ytId)/hqdefault.jpg")
        }
    }
    
    private func getYouTubeId(from url: String) -> String? {
        let pattern = "^.*(youtu.be\\/|v\\/|u\\/\\w\\/|embed\\/|watch\\?v=|&v=)([^#&?]*).*"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let nsString = url as NSString
            let range = NSRange(location: 0, length: nsString.length)
            
            if let match = regex.firstMatch(in: url, options: [], range: range), match.numberOfRanges > 2 {
                let id = nsString.substring(with: match.range(at: 2))
                return id.count == 11 ? id : nil
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        return nil
    }
}

#Preview {
    VideoPreviewView(
        videoUrl: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        onPlay: {}
    )
    .padding()
}
