import SwiftUI

// MARK: - Reading Preferences Sheet ("Aa")

/// Editorial Teal (design canvas · "14 · Preferenze lettura"): a sheet over
/// the dimmed article — typeface cards, text size, line spacing and reader
/// theme. Every control applies immediately; "Done" only closes the sheet.
struct ReadingPreferencesView: View {
    @Binding var preferences: ReadingPreferences
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(themeManager.colors.line)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .accessibilityHidden(true)

            HStack {
                Text("Reading preferences")
                    .font(Typography.ui(17, weight: .bold, relativeTo: .headline))
                    .foregroundColor(themeManager.colors.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Done") { dismiss() }
                    .font(Typography.ui(15, weight: .semibold))
                    .foregroundColor(themeManager.colors.accent)
                    .buttonStyle(.plain)
                    .minimumTapTarget()
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    typefaceControl
                    sizeControl
                    spacingControl
                    themeControl
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .background(themeManager.colors.page)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(Typography.ui(13, weight: .semibold, relativeTo: .footnote))
            .foregroundColor(themeManager.colors.accent2)
    }

    // MARK: Typeface

    private var typefaceControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Typeface")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                spacing: 10
            ) {
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
            VStack(spacing: 4) {
                Text("Ag")
                    .font(family.font(size: 22))
                Text(family.displayName)
                    .font(Typography.ui(12.5, weight: isSelected ? .semibold : .medium, relativeTo: .caption))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(themeManager.colors.text)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(isSelected ? themeManager.colors.accent200 : themeManager.colors.page)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isSelected ? themeManager.colors.accent : themeManager.colors.line,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(family.displayName) typeface")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: Size

    private var sizeControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionLabel("Text size")
                Spacer()
                Text(preferences.fontSizeFormatted)
                    .font(Typography.ui(13, weight: .semibold))
                    .foregroundColor(themeManager.colors.accent)
            }

            HStack(spacing: 12) {
                Text("A")
                    .font(Typography.ui(13, weight: .semibold))
                    .foregroundColor(themeManager.colors.text)
                    .accessibilityHidden(true)

                PillSlider(
                    value: Binding(
                        get: { preferences.fontSize },
                        set: { preferences.fontSize = $0 }
                    ),
                    range: 14...28,
                    step: 0.5,
                    accessibilityLabel: "Text size",
                    trackColor: themeManager.colors.line,
                    fillColor: themeManager.colors.accent,
                    knobFillColor: Color.white,
                    knobBorderColor: themeManager.colors.accent
                )

                Text("A")
                    .font(Typography.ui(22, weight: .semibold, relativeTo: .title2))
                    .foregroundColor(themeManager.colors.text)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Spacing

    private var spacingControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Line spacing")

            HStack(spacing: 2) {
                ForEach(Typography.LineHeight.allCases, id: \.self) { height in
                    spacingSegment(height)
                }
            }
            .padding(3)
            .background(themeManager.colors.surface)
            .clipShape(Capsule())
        }
    }

    private func spacingSegment(_ height: Typography.LineHeight) -> some View {
        let isSelected = preferences.lineHeight == height
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { preferences.lineHeight = height }
        }) {
            Text(height.displayName)
                .font(Typography.ui(13.5, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? themeManager.colors.text : themeManager.colors.muted)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(isSelected ? themeManager.colors.page : Color.clear)
                .clipShape(Capsule())
                .shadow(color: isSelected ? Color(hex: "#16191A").opacity(0.12) : .clear, radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel("\(height.displayName) spacing")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: Theme

    private var themeControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Theme")

            HStack(spacing: 10) {
                themeSwatch(.cream)
                themeSwatch(.sepia)
                themeSwatch(.dark)
            }
        }
    }

    private func themeSwatch(_ theme: ColorTheme) -> some View {
        let isSelected = preferences.colorTheme == theme
        let swatchColors = themeManager.colors(for: theme)
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { preferences.colorTheme = theme }
        }) {
            Text(theme.displayName)
                .font(Typography.ui(14, weight: isSelected ? .semibold : .medium))
                .foregroundColor(swatchColors.text)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(swatchColors.page)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSelected ? themeManager.colors.accent : themeManager.colors.line,
                            lineWidth: isSelected ? 2 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.displayName) theme")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
    var step: CGFloat = 1
    var accessibilityLabel: String = "Value"
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
            .frame(maxHeight: .infinity)
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
        // The visible track is 6pt and the knob 24pt; the gesture area spans
        // the HIG minimum 44pt so the knob is easy to grab.
        .frame(height: Spacing.minTapTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValueText)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private var accessibilityValueText: String {
        String(format: "%.1f", value)
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
                            .foregroundColor(themeManager.colors.accent)
                            .minimumTapTarget()
                    }
                    .buttonStyle(.plain)
                    .disabled(newTag.isEmpty)
                    .accessibilityLabel("Add tag")
                }
                .padding()
                
                // Tag Cloud
                ScrollView {
                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(Typography.symbol(14))
                                Button(action: { removeTag(tag) }) {
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .frame(minWidth: 28, minHeight: 28)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove tag \(tag)")
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
