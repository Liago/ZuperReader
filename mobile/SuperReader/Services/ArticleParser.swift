import Foundation

// MARK: - Article Parser Service

actor ArticleParser {
    static let shared = ArticleParser()
    
    private init() {}
    
    func parseUrl(_ urlString: String) async throws -> ParseResult {
        guard let url = URL(string: SupabaseConfig.parseFunctionUrl) else {
            throw ParserError.invalidUrl
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["url": urlString])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParserError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ParserError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(ParseResult.self, from: data)
        
        return result
    }
}

// MARK: - Parser Errors

enum ParserError: LocalizedError {
    case invalidUrl
    case invalidResponse
    case serverError(statusCode: Int)
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode):
            return "Server error: \(statusCode)"
        case .parsingFailed:
            return "Failed to parse article"
        }
    }
}
