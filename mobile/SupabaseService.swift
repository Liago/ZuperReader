import Foundation

struct Article: Identifiable, Codable {
    let id: String
    let user_id: String
    let url: String
    let title: String
    let content: String?
    let excerpt: String?
    let image_url: String?
    let favicon_url: String?
    let author: String?
    let published_date: String?
    let domain: String?
    let tags: [String]
    let is_favorite: Bool
    let like_count: Int
    let comment_count: Int
    let reading_status: String
    let estimated_read_time: Int?
    let is_public: Bool
    let scraped_at: String
    let created_at: String
    let updated_at: String
}

struct ParseResult: Codable {
    let url: String
    let title: String?
    let content: String?
    let excerpt: String?
    let lead_image_url: String?
    let author: String?
    let date_published: String?
    let domain: String?
    let word_count: Int?
}

class SupabaseService {
    static let shared = SupabaseService()
    
    private let supabaseUrl = "https://wjotvfawhnibnjgoaqud.supabase.co"
    private let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indqb3R2ZmF3aG5pYm5qZ29hcXVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTA0NDMxMDcsImV4cCI6MjAwNjAxOTEwN30.xtirkUL9f4ciRcJNvwtkGuWGTMcTfRKD3KW9kdZWBpo"
    
    // Parse function URL (update this after deploying to Netlify)
    private let parseFunctionUrl = "https://your-netlify-site.netlify.app/.netlify/functions/parse"
    
    func fetchArticles(userId: String, completion: @escaping (Result<[Article], Error>) -> Void) {
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/articles?user_id=eq.\(userId)&order=created_at.desc") else { return }
        
        var request = URLRequest(url: url)
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let articles = try JSONDecoder().decode([Article].self, from: data)
                completion(.success(articles))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func parseUrl(_ urlString: String, completion: @escaping (Result<ParseResult, Error>) -> Void) {
        guard let url = URL(string: parseFunctionUrl) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["url": urlString])
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let result = try JSONDecoder().decode(ParseResult.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func saveArticle(parsedData: ParseResult, userId: String, completion: @escaping (Result<Article, Error>) -> Void) {
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/articles") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let domain = URL(string: parsedData.url)?.host ?? ""
        let estimatedReadTime = parsedData.word_count.map { Int(ceil(Double($0) / 200.0)) }
        
        let articleData: [String: Any?] = [
            "user_id": userId,
            "url": parsedData.url,
            "title": parsedData.title ?? "Untitled",
            "content": parsedData.content,
            "excerpt": parsedData.excerpt,
            "image_url": parsedData.lead_image_url,
            "author": parsedData.author,
            "published_date": parsedData.date_published,
            "domain": domain,
            "estimated_read_time": estimatedReadTime
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: articleData.compactMapValues { $0 })
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let articles = try JSONDecoder().decode([Article].self, from: data)
                if let article = articles.first {
                    completion(.success(article))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func deleteArticle(articleId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/articles?id=eq.\(articleId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }.resume()
    }
    
    func toggleFavorite(articleId: String, isFavorite: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(supabaseUrl)/rest/v1/articles?id=eq.\(articleId)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["is_favorite": isFavorite])
        
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }.resume()
    }
}
