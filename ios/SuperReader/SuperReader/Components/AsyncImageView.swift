import SwiftUI

// MARK: - Enhanced Async Image

struct AsyncImageView: View {
    let url: String?
    let contentMode: ContentMode
    let cornerRadius: CGFloat
    
    @State private var loadedImage: Image?
    @State private var isLoading = true
    @State private var loadFailed = false
    
    init(
        url: String?,
        contentMode: ContentMode = .fill,
        cornerRadius: CGFloat = CornerRadius.md
    ) {
        self.url = url
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        ZStack {
            if let loadedImage = loadedImage {
                loadedImage
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if loadFailed || url == nil {
                placeholderView
            } else {
                loadingView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onAppear(perform: loadImage)
    }
    
    private var loadingView: some View {
        ZStack {
            Color.gray.opacity(0.1)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Image(systemName: "photo")
                .font(.system(size: 30))
                .foregroundColor(.gray.opacity(0.4))
        }
    }
    
    private func loadImage() {
        guard let urlString = url,
              let imageUrl = URL(string: urlString) else {
            loadFailed = true
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: imageUrl) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let data = data,
                   let uiImage = UIImage(data: data) {
                    self.loadedImage = Image(uiImage: uiImage)
                } else {
                    self.loadFailed = true
                }
            }
        }.resume()
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let imageUrl: String?
    let initials: String
    let size: CGFloat
    let gradient: LinearGradient
    
    init(
        imageUrl: String? = nil,
        initials: String = "??",
        size: CGFloat = 40,
        gradient: LinearGradient = PremiumGradients.purple
    ) {
        self.imageUrl = imageUrl
        self.initials = initials
        self.size = size
        self.gradient = gradient
    }
    
    var body: some View {
        ZStack {
            if let url = imageUrl {
                AsyncImageView(url: url, cornerRadius: size / 2)
            } else {
                Circle()
                    .fill(gradient)
                
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    VStack(spacing: 20) {
        AsyncImageView(
            url: "https://picsum.photos/200",
            cornerRadius: 12
        )
        .frame(width: 200, height: 150)
        
        AsyncImageView(url: nil)
            .frame(width: 200, height: 150)
        
        HStack(spacing: 16) {
            AvatarView(initials: "JD", size: 50)
            AvatarView(initials: "AZ", size: 40, gradient: PremiumGradients.pink)
            AvatarView(initials: "SR", size: 60, gradient: PremiumGradients.indigo)
        }
    }
    .padding()
}
