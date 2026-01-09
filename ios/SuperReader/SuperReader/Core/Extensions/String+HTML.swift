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
}
