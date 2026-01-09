import SwiftUI
import Auth

struct ArticleLinkPreviewView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var parseResult: ParseResult?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var isSaved = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(message: error)
                    } else if let result = parseResult {
                        articleContent(result)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(themeManager.colors.bgPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(themeManager.colors.textSecondary)
                            .font(.title2)
                    }
                }
                
                if let result = parseResult {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: saveArticle) {
                            if isSaving {
                                ProgressView()
                            } else {
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                    .foregroundStyle(isSaved ? Color.green : themeManager.colors.textSecondary)
                            }
                        }
                        .disabled(isSaving || isSaved)
                    }
                }
            }
        }
        .task {
            await parseLink()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 100)
            
            ProgressView()
                .scaleEffect(1.2)
                .tint(themeManager.colors.accent)
            
            Text("Generating Preview...")
                .font(.headline)
                .foregroundStyle(themeManager.colors.textSecondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .background(
                    Circle()
                        .fill(.orange.opacity(0.1))
                        .frame(width: 96, height: 96)
                )
            
            VStack(spacing: 8) {
                Text("Preview Unavailable")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(themeManager.colors.textPrimary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(themeManager.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Open in Browser") {
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.colors.accent)
            .padding(.top)
            
            Spacer()
        }
        .padding()
    }
    
    private func articleContent(_ result: ParseResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero Image
            if let imageUrl = result.leadImageUrl, let imgUrl = URL(string: imageUrl) {
                AsyncImageView(url: imgUrl.absoluteString, cornerRadius: 0)
                    .aspectRatio(1.5, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [.black.opacity(0.6), .clear]),
                            startPoint: .bottom,
                            endPoint: .center
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 20) {
                // Header Info
                VStack(alignment: .leading, spacing: 12) {
                    // Metadata Badges
                    HStack(spacing: 12) {
                        if let domain = result.domain {
                            Label(domain, systemImage: "globe")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(themeManager.colors.bgSecondary)
                                .foregroundColor(themeManager.colors.textSecondary)
                                .clipShape(Capsule())
                        }
                        
                        if let dateStr = result.datePublished, let formattedDate = formatDate(dateStr) {
                            Text(formattedDate)
                                .font(.caption)
                                .foregroundStyle(themeManager.colors.textSecondary)
                        }
                    }
                    
                    Text(result.title ?? "Untitled Article")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(themeManager.colors.textPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let author = result.author {
                        Text("By \(author)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(themeManager.colors.textSecondary)
                    }
                }
                
                Divider()
                    .overlay(themeManager.colors.border)
                
                // Excerpt
                if let excerpt = result.excerpt {
                    Text(excerpt)
                        .font(.body)
                        .foregroundStyle(themeManager.colors.textPrimary.opacity(0.9))
                        .lineSpacing(6)
                        .padding(.vertical, 4)
                }
                
                // Primary Action
                Button(action: {
                    UIApplication.shared.open(url)
                }) {
                    HStack {
                        Text("Read Original")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeManager.colors.accent)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: themeManager.colors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .padding(24)
            .background(themeManager.colors.bgPrimary)
            // Pull up content over image slightly if image exists
            .offset(y: result.leadImageUrl != nil ? -20 : 0)
            .cornerRadius(result.leadImageUrl != nil ? 24 : 0, corners: [.topLeft, .topRight])
        }
    }
    
    private func parseLink() async {
        isLoading = true
        do {
            parseResult = try await SupabaseService.shared.parseArticleUrl(url.absoluteString)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func saveArticle() {
        guard let result = parseResult, let userId = AuthManager.shared.user?.id.uuidString else { return }
        
        isSaving = true
        Task {
            do {
                _ = try await SupabaseService.shared.saveArticle(parsedData: result, userId: userId)
                await MainActor.run {
                    isSaved = true
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                print("Failed to save: \(error)")
                isSaving = false
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String? {
        // Try ISO8601 first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        // Try standard ISO
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        
        return nil
    }
}

// Helper for rounded corners on specific sides
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
