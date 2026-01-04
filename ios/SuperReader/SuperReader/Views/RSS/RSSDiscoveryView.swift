import SwiftUI

struct RSSDiscoveryView: View {
    @StateObject private var viewModel = RSSDiscoveryViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var onSubscribe: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search website or paste URL", text: $viewModel.query) // "enter" to search?
                        .onSubmit {
                            Task { await viewModel.search() }
                        }
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    
                    if !viewModel.query.isEmpty {
                        Button(action: { viewModel.query = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(themeManager.colors.bgSecondary)
                .cornerRadius(10)
                .padding()
                
                // Content
                ZStack {
                    if viewModel.isSearching {
                        ProgressView("Searching...")
                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            Text(error)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    } else if viewModel.results.isEmpty && !viewModel.query.isEmpty {
                         // Show nothing or "No results" if query was submitted?
                         // Current logic sets errorMessage on empty results.
                    } else {
                        List {
                            ForEach(viewModel.results) { feed in
                                DiscoveredFeedRow(feed: feed, viewModel: viewModel)
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Add Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                viewModel.onSubscribe = self.onSubscribe
            }
            .overlay(alignment: .bottom) {
                if let success = viewModel.successMessage {
                    Text(success)
                        .padding()
                        .background(Color.green.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    viewModel.successMessage = nil
                                }
                            }
                        }
                }
            }
        }
    }
}

struct DiscoveredFeedRow: View {
    let feed: DiscoveredFeed
    @ObservedObject var viewModel: RSSDiscoveryViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(feed.title)
                    .font(.headline)
                    .foregroundColor(themeManager.colors.textPrimary)
                Text(feed.url)
                    .font(.caption)
                    .foregroundColor(themeManager.colors.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                Task { await viewModel.subscribe(to: feed) }
            }) {
                if viewModel.isSubscribing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Follow")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(themeManager.colors.accent)
                        .cornerRadius(16)
                }
            }
            .buttonStyle(.plain) // Prevent row selection
        }
        .padding(.vertical, 4)
    }
}
