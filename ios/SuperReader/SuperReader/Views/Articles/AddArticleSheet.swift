import SwiftUI
import Supabase


// MARK: - Add Article Sheet

struct AddArticleSheet: View {
    let onArticleAdded: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthManager.shared
    
    @State private var url = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var parseResult: ParseResult?
    @State private var showPreview = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // URL Input
                        urlInputSection
                        
                        // Preview (if available)
                        if let result = parseResult {
                            previewSection(result)
                        }
                        
                        // Error
                        if let error = errorMessage {
                            errorSection(error)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if parseResult != nil {
                        Button("Save") {
                            Task { await saveArticle() }
                        }
                        .disabled(isLoading)
                    }
                }
            }
        }
    }
    
    // MARK: - URL Input Section
    
    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Article URL")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.colors.textSecondary)
            
            HStack(spacing: Spacing.sm) {
                Image(systemName: "link")
                    .foregroundColor(themeManager.colors.textSecondary)
                
                TextField("https://example.com/article", text: $url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                
                if !url.isEmpty {
                    Button(action: { url = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(themeManager.colors.bgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(themeManager.colors.border, lineWidth: 1)
            )
            
            // Parse button
            GradientButton(
                title: parseResult != nil ? "Re-parse URL" : "Parse URL",
                icon: "arrow.down.doc",
                isLoading: isLoading
            ) {
                Task { await parseUrl() }
            }
            .disabled(url.isEmpty || isLoading)
            
            // Paste from clipboard hint
            Button(action: pasteFromClipboard) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Paste from clipboard")
                }
                .font(.system(size: 14))
                .foregroundColor(themeManager.colors.accent)
            }
        }
    }
    
    // MARK: - Preview Section
    
    private func previewSection(_ result: ParseResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Preview")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.colors.textSecondary)
            
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Image
                if let imageUrl = result.leadImageUrl {
                    AsyncImageView(url: imageUrl, cornerRadius: CornerRadius.md)
                        .frame(height: 180)
                }
                
                // Title
                Text(result.title ?? "Untitled")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                // Domain
                if let domain = result.domain {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                        Text(domain)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(themeManager.colors.accent)
                }
                
                // Excerpt
                if let excerpt = result.excerpt {
                    Text(excerpt)
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.colors.textSecondary)
                        .lineLimit(3)
                }
                
                // Meta info
                HStack(spacing: Spacing.md) {
                    if let author = result.author {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                                .font(.system(size: 11))
                            Text(author)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(themeManager.colors.textSecondary)
                    }
                    
                    if let wordCount = result.wordCount {
                        let readTime = Int(ceil(Double(wordCount) / 200.0))
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text("\(readTime) min read")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(themeManager.colors.textSecondary)
                    }
                }
            }
            .padding()
            .background(themeManager.colors.bgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Error Section
    
    private func errorSection(_ error: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(error)
                .font(.system(size: 14))
                .foregroundColor(.red)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }
    
    // MARK: - Actions
    
    private func pasteFromClipboard() {
        if let clipboardString = UIPasteboard.general.string {
            url = clipboardString
        }
    }
    
    private func parseUrl() async {
        guard !url.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        parseResult = nil
        
        // Ensure URL has protocol
        var urlToUse = url
        if !urlToUse.hasPrefix("http://") && !urlToUse.hasPrefix("https://") {
            urlToUse = "https://" + urlToUse
        }
        
        do {
            let result = try await ArticleParser.shared.parseUrl(urlToUse)
            parseResult = result
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func saveArticle() async {
        guard let result = parseResult,
              let userId = authManager.user?.id.uuidString else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await SupabaseService.shared.saveArticle(parsedData: result, userId: userId)
            onArticleAdded()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    AddArticleSheet(onArticleAdded: {})
        .environmentObject(ThemeManager.shared)
}
