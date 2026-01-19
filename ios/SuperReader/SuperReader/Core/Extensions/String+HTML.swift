import Foundation
import UIKit

extension String {
    var decodedHTML: String {
        // Force UTF-8 encoding by adding meta tag
        let htmlWithStyle = """
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: -apple-system; font-size: 16px; }
            </style>
        </head>
        <body>\(self)</body>
        </html>
        """
        
        guard let data = htmlWithStyle.data(using: .utf8) else { return self }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return self
    }

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
