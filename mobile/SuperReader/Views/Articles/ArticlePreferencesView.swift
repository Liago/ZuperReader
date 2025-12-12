import SwiftUI

// MARK: - Reading Preferences View

struct ReadingPreferencesView: View {
    @Binding var preferences: ReadingPreferences
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // Font Size Section
                Section(header: Text("Text Size")) {
                    HStack {
                        Image(systemName: "textformat.size.smaller")
                        Slider(value: Binding(
                            get: { self.preferences.fontSize },
                            set: { self.preferences.fontSize = $0 }
                        ), in: 12...32, step: 2)
                        Image(systemName: "textformat.size.larger")
                    }
                    .padding(.vertical, 8)
                }
                
                // Font Family Section
                Section(header: Text("Font")) {
                    ForEach(Typography.FontFamily.allCases, id: \.self) { font in
                        HStack {
                            Text(font.displayName)
                                .font(font.font(size: 16))
                            Spacer()
                            if preferences.fontFamily == font {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                preferences.fontFamily = font
                            }
                        }
                    }
                }
                
                // Theme Section
                Section(header: Text("Article Theme")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ColorTheme.allCases, id: \.self) { theme in
                                ThemeCircle(theme: theme, isSelected: preferences.colorTheme == theme) {
                                    withAnimation {
                                        preferences.colorTheme = theme
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Line Height Section
                Section(header: Text("Line Height")) {
                    Picker("Line Height", selection: $preferences.lineHeight) {
                        ForEach(Typography.LineHeight.allCases, id: \.self) { height in
                            Text(height.displayName).tag(height)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Preview
                Section(header: Text("Preview")) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("The quick brown fox jumps over the lazy dog.")
                            .font(preferences.fontFamily.font(size: preferences.fontSize))
                            .lineSpacing(preferences.fontSize * (preferences.lineHeight.multiplier - 1))
                            .foregroundColor(preferences.colorTheme.colors.textPrimary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(preferences.colorTheme.colors.bgPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .navigationTitle("Reading Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ThemeCircle: View {
    let theme: ColorTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(theme.colors.bgPrimary)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(theme.colors.textPrimary)
                }
            }
        }
    }
}

// MARK: - Tag Management View

struct TagManagementView: View {
    let currentTags: [String]
    let onSave: ([String]) -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var tags: [String] = []
    @State private var newTag = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                // Tag Input
                HStack {
                    TextField("Add new tag...", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addTag)
                    
                    Button(action: addTag) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(newTag.isEmpty)
                }
                .padding()
                
                // Tag Cloud
                ScrollView {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.system(size: 14))
                                Button(action: { removeTag(tag) }) {
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(themeManager.colors.accent.opacity(0.1))
                            .foregroundColor(themeManager.colors.accent)
                            .clipShape(Capsule())
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Manage Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(tags)
                        dismiss()
                    }
                }
            }
            .onAppear {
                tags = currentTags
            }
        }
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !tags.contains(trimmed) {
            withAnimation {
                tags.append(trimmed)
                newTag = ""
            }
        }
    }
    
    private func removeTag(_ tag: String) {
        withAnimation {
            tags.removeAll { $0 == tag }
        }
    }
}

// Helper for Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for row in rows {
            if let maxAscent = row.map({ $0.dimensions(in: .unspecified) }).map({ $0.height }).max() {
                height += maxAscent + spacing
            }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.dimensions(in: .unspecified).height }.max() ?? 0
            
            for view in row {
                view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += view.dimensions(in: .unspecified).width + spacing
            }
            y += rowHeight + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentRow = 0
        var remainingWidth = proposal.width ?? 0
        
        for view in subviews {
            let viewSize = view.dimensions(in: .unspecified)
            if viewSize.width > remainingWidth {
                currentRow += 1
                rows.append([])
                remainingWidth = proposal.width ?? 0
            }
            rows[currentRow].append(view)
            remainingWidth -= (viewSize.width + spacing)
        }
        return rows
    }
}
