import SwiftUI

// MARK: - Reading Preferences Sheet (05)

/// Half-height sheet over the dimmed article — every control applies
/// immediately, there is no Done-to-commit step (docs/revamp-ios/README.md ·
/// "05 Reading preferences sheet").
struct ReadingPreferencesView: View {
    @Binding var preferences: ReadingPreferences
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(themeManager.colors.line)
                .frame(width: 42, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    sizeControl
                    typefaceControl
                    spacingControl
                    themeControl
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
        }
        .background(themeManager.colors.card)
        .cornerRadius(CornerRadius.sheet, corners: [.topLeft, .topRight])
    }

    // MARK: Size

    private var sizeControl: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Size")
                    .font(Typography.sectionLabel)
                    .textCase(.uppercase)
                    .foregroundColor(themeManager.colors.muted)
                Spacer()
                Text(preferences.fontSizeFormatted)
                    .font(Typography.figtree(13, weight: .bold))
                    .foregroundColor(themeManager.colors.accent700)
            }

            PillSlider(
                value: Binding(
                    get: { preferences.fontSize },
                    set: { preferences.fontSize = $0 }
                ),
                range: 14...28,
                trackColor: themeManager.colors.line,
                fillColor: themeManager.colors.accent,
                knobFillColor: themeManager.colors.accent,
                knobBorderColor: themeManager.colors.card
            )
        }
    }

    // MARK: Typeface

    private var typefaceControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Typeface")
                .font(Typography.sectionLabel)
                .textCase(.uppercase)
                .foregroundColor(themeManager.colors.muted)

            HStack(spacing: 10) {
                ForEach(Typography.FontFamily.allCases, id: \.self) { family in
                    typefaceCard(family)
                }
            }
        }
    }

    private func typefaceCard(_ family: Typography.FontFamily) -> some View {
        let isSelected = preferences.fontFamily == family
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { preferences.fontFamily = family }
        }) {
            VStack(spacing: 8) {
                Text("Aa")
                    .font(family.font(size: 19))
                Text(family.displayName)
                    .font(Typography.figtree(11.5, weight: .heavy))
            }
            .foregroundColor(isSelected ? themeManager.colors.page : themeManager.colors.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? themeManager.colors.text : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(isSelected ? Color.clear : themeManager.colors.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Spacing

    private var spacingControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spacing")
                .font(Typography.sectionLabel)
                .textCase(.uppercase)
                .foregroundColor(themeManager.colors.muted)

            HStack(spacing: 4) {
                ForEach(Typography.LineHeight.allCases, id: \.self) { height in
                    spacingSegment(height)
                }
            }
            .padding(4)
            .background(themeManager.colors.sink)
            .clipShape(Capsule())
        }
    }

    private func spacingSegment(_ height: Typography.LineHeight) -> some View {
        let isSelected = preferences.lineHeight == height
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { preferences.lineHeight = height }
        }) {
            Text(height.displayName)
                .font(Typography.figtree(13.5, weight: .semibold))
                .foregroundColor(isSelected ? themeManager.colors.text : themeManager.colors.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? themeManager.colors.card : Color.clear)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color.black.opacity(0.1) : .clear, radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: Theme

    private var themeControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(Typography.sectionLabel)
                .textCase(.uppercase)
                .foregroundColor(themeManager.colors.muted)

            HStack(spacing: 10) {
                themeSwatch(.cream)
                themeSwatch(.sepia)
                themeSwatch(.dark)
            }
        }
    }

    private func themeSwatch(_ theme: ColorTheme) -> some View {
        let isSelected = preferences.colorTheme == theme
        let swatchColors = theme.colors
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { preferences.colorTheme = theme }
        }) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .fill(swatchColors.page)
                    .frame(height: 52)
                Text(theme.displayName)
                    .font(Typography.figtree(11, weight: .bold))
                    .foregroundColor(swatchColors.text)
                    .padding(8)
            }
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(themeManager.colors.line, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .inset(by: 2)
                    .stroke(themeManager.colors.accent, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pill Slider

/// A 6pt track with a 24pt knob (4pt border) — the slider styling from
/// docs/revamp-ios/README.md · "05 Reading preferences sheet" isn't
/// achievable with a stock `Slider`, so this drives a bound value directly
/// off drag location.
struct PillSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let trackColor: Color
    let fillColor: Color
    let knobFillColor: Color
    let knobBorderColor: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let knobX = width * fraction

            ZStack(alignment: .leading) {
                Capsule().fill(trackColor).frame(height: 6)
                Capsule().fill(fillColor).frame(width: max(0, knobX), height: 6)
                Circle()
                    .fill(knobFillColor)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(knobBorderColor, lineWidth: 4))
                    .offset(x: knobX - 12)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let clampedX = min(max(0, drag.location.x), width)
                        let newFraction = clampedX / width
                        value = range.lowerBound + newFraction * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: 24)
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
            .onChange(of: currentTags) { newValue in
                tags = newValue
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
