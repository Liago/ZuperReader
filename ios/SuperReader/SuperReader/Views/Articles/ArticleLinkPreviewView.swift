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
            VStack {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Analyzing Link...")
                            .foregroundColor(.secondary)
                    }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text("Could not parse article")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Open in Browser") {
                            UIApplication.shared.open(url)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else if let result = parseResult {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let imageUrl = result.leadImageUrl, let imgUrl = URL(string: imageUrl) {
                                AsyncImageView(url: imgUrl.absoluteString, cornerRadius: 12)
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text(result.title ?? "Untitled Article")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(themeManager.colors.textPrimary)
                                
                                if let domain = result.domain {
                                    Text(domain)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(themeManager.colors.bgSecondary)
                                        .cornerRadius(4)
                                }
                                
                                if let excerpt = result.excerpt {
                                    Text(excerpt)
                                        .font(.body)
                                        .foregroundColor(themeManager.colors.textSecondary)
                                        .lineSpacing(4)
                                }
                                
                                Button(action: saveArticle) {
                                    HStack {
                                        if isSaving {
                                            ProgressView()
                                                .tint(.white)
                                        } else if isSaved {
                                            Image(systemName: "checkmark")
                                            Text("Saved to Library")
                                        } else {
                                            Image(systemName: "bookmark.fill")
                                            Text("Save Article")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isSaved ? Color.green : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(isSaving || isSaved)
                                .padding(.top, 10)
                                
                                Button("Read Original") {
                                    UIApplication.shared.open(url)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(themeManager.colors.accent)
                                .padding(.top, 8)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Link Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await parseLink()
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
                    // Auto dismiss after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                print("Failed to save: \(error)")
                isSaving = false
            }
        }
    }
}
