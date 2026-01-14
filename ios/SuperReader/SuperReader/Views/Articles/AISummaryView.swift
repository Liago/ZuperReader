import SwiftUI

struct AISummaryView: View {
    let article: Article
    let fontFamily: Typography.FontFamily // Use correct type
    let onGenerate: (String, String) -> Void // Passes length and format
    let isGenerating: Bool
    let error: String?
    
    @State private var selectedLength: String = "medium"
    @State private var selectedFormat: String = "summary"
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.blue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Riassunto AI")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple, Color.blue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        if let dateStr = article.aiSummaryGeneratedAt {
                            // Parse and format date
                            Text(formatDate(dateStr))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            
            // Content
            if let summary = article.aiSummary {
                ScrollView {
                    Text(summary)
                        .font(fontFamily.font(size: 16)) // Use custom font
                        .lineSpacing(4)
                        .foregroundColor(.primary)
                        .padding(.vertical, 4)
                }
            } else if !isGenerating {
                VStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("Nessun riassunto AI disponibile")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Tappa su \"Genera\" per creare un riassunto intelligente")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            
            if isGenerating {
               HStack {
                   Spacer()
                   ProgressView()
                   .padding(.trailing, 8)
                   Text("Generazione in corso...")
                       .font(.subheadline)
                       .foregroundColor(.secondary)
                   Spacer()
               }
               .padding(.vertical, 8)
            }
            
            // Error
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Controls
            HStack {
                // Length Menu
                Menu {
                    Button(action: { selectedLength = "short" }) {
                        Label("Breve", systemImage: selectedLength == "short" ? "checkmark" : "")
                    }
                    Button(action: { selectedLength = "medium" }) {
                           Label("Medio", systemImage: selectedLength == "medium" ? "checkmark" : "")
                    }
                    Button(action: { selectedLength = "long" }) {
                           Label("Lungo", systemImage: selectedLength == "long" ? "checkmark" : "")
                    }
                } label: {
                    HStack {
                        Text(lengthLabel(selectedLength))
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                // Format Menu
                Menu {
                    Button(action: { selectedFormat = "summary" }) {
                        Label("Riassunto", systemImage: selectedFormat == "summary" ? "checkmark" : "")
                    }
                    Button(action: { selectedFormat = "bullet" }) {
                        Label("Punti Elenco", systemImage: selectedFormat == "bullet" ? "checkmark" : "")
                    }
                } label: {
                    HStack {
                        Text(formatLabel(selectedFormat))
                        Image(systemName: "chevron.down")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: {
                    onGenerate(selectedLength, selectedFormat)
                }) {
                    HStack {
                        if isGenerating {
                             ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(article.aiSummary == nil ? "Genera" : "Rigenera")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.purple, Color.blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(8)
                    .opacity(isGenerating ? 0.7 : 1.0)
                }
                .disabled(isGenerating)
            }
            
            // Footer
            HStack(spacing: 4) {
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.caption2)
                Text("Powered by Cohere AI")
                    .font(.caption2)
                Spacer()
            }
            .foregroundColor(.secondary)
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.3)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private func lengthLabel(_ length: String) -> String {
        switch length {
        case "short": return "Breve"
        case "medium": return "Medio"
        case "long": return "Lungo"
        default: return "Medio"
        }
    }
    
    private func formatLabel(_ format: String) -> String {
        switch format {
        case "summary": return "Riassunto"
        case "bullet": return "Punti Elenco"
        default: return "Riassunto"
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
         let formatter = ISO8601DateFormatter()
         formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
         if let date = formatter.date(from: dateString) {
             let displayFormatter = DateFormatter()
             displayFormatter.dateStyle = .medium
             displayFormatter.timeStyle = .short
             return "Generato il " + displayFormatter.string(from: date)
         }
         return ""
    }
}
