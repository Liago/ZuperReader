import Foundation

extension String {
    func strippingHTML() -> String {
        // 1. Remove HTML tags
        let stripped = self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        
        // 2. Decode common HTML entities (basic subset)
        // A full proper decode requires NSAttributedString which can be slow, 
        // but for snippets this simple replacement is often sufficient and much faster.
        return stripped
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "â€™", with: "'") // Common encoding artifact
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
