import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ArticleViewModel()
    @State private var newArticleURL = ""
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Enter article URL", text: $newArticleURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                    
                    Button(action: {
                        viewModel.addArticle(url: newArticleURL)
                        newArticleURL = ""
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .disabled(newArticleURL.isEmpty)
                }
                .padding()
                
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }
                
                List(viewModel.articles) { article in
                    VStack(alignment: .leading, spacing: 8) {
                        if let imageUrl = article.lead_image_url, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                     .aspectRatio(contentMode: .fill)
                                     .frame(height: 150)
                                     .clipped()
                            } placeholder: {
                                Color.gray.opacity(0.3)
                            }
                            .cornerRadius(8)
                        }
                        
                        Text(article.title)
                            .font(.headline)
                        
                        if let excerpt = article.excerpt {
                            Text(excerpt)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .refreshable {
                    viewModel.loadArticles()
                }
            }
            .navigationTitle("SuperReader")
            .onAppear {
                viewModel.loadArticles()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
