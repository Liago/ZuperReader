import Foundation

struct ContentBlock: Identifiable {
    let id = UUID()
    let type: BlockType
    
    enum BlockType {
        case html(String)
        case video(url: String)
    }
}


class ContentParser {
    static let shared = ContentParser()
    
    private init() {}
    
    func parse(content: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        
        // Regex to capture iframe and video tags
        // This is a simplified regex, but should cover most standard embed codes
        let pattern = "(<iframe.*?</iframe>|<video.*?</video>)"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let nsString = content as NSString
            let results = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
            
            var lastIndex = 0
            
            for result in results {
                // Add text before the match
                if result.range.location > lastIndex {
                    let textRange = NSRange(location: lastIndex, length: result.range.location - lastIndex)
                    let textPart = nsString.substring(with: textRange)
                    if !textPart.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        blocks.append(ContentBlock(type: .html(textPart)))
                    }
                }
                
                // Process the match (iframe/video)
                let matchRange = result.range
                let matchString = nsString.substring(with: matchRange)
                
                if let src = extractSrc(from: matchString) {
                    blocks.append(ContentBlock(type: .video(url: src)))
                } else {
                    // Fallback: if we can't extract src, just render as HTML
                    blocks.append(ContentBlock(type: .html(matchString)))
                }
                
                lastIndex = matchRange.location + matchRange.length
            }
            
            // Add remaining text
            if lastIndex < nsString.length {
                let textRange = NSRange(location: lastIndex, length: nsString.length - lastIndex)
                let textPart = nsString.substring(with: textRange)
                if !textPart.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(ContentBlock(type: .html(textPart)))
                }
            }
            
        } catch {
            print("Regex error: \(error)")
            return [ContentBlock(type: .html(content))] // Fallback to single block
        }
        
        return blocks.isEmpty ? [ContentBlock(type: .html(content))] : blocks
    }
    
    private func extractSrc(from tag: String) -> String? {
        let pattern = "src=[\"'](.*?)[\"']"
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let nsString = tag as NSString
            let results = regex.matches(in: tag, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let result = results.first, result.numberOfRanges > 1 {
                return nsString.substring(with: result.range(at: 1))
            }
        } catch {
            print("Src extraction error: \(error)")
        }
        return nil
    }
}
