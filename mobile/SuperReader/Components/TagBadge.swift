import SwiftUI

// MARK: - Tag Badge

struct TagBadge: View {
    let tag: String
    let isSelected: Bool
    let onTap: (() -> Void)?
    
    @EnvironmentObject var themeManager: ThemeManager
    
    init(tag: String, isSelected: Bool = false, onTap: (() -> Void)? = nil) {
        self.tag = tag
        self.isSelected = isSelected
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            Text(tag)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : themeManager.colors.accent)
                .padding(.horizontal, Spacing.sm + 2)
                .padding(.vertical, Spacing.xs + 2)
                .background(
                    isSelected
                    ? AnyView(PremiumGradients.purple)
                    : AnyView(themeManager.colors.accent.opacity(0.1))
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(themeManager.colors.accent.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}

// MARK: - Tag List

struct TagListView: View {
    let tags: [String]
    let maxVisible: Int
    let selectedTags: [String]
    let onTagTap: ((String) -> Void)?
    
    @EnvironmentObject var themeManager: ThemeManager
    
    init(
        tags: [String],
        maxVisible: Int = 3,
        selectedTags: [String] = [],
        onTagTap: ((String) -> Void)? = nil
    ) {
        self.tags = tags
        self.maxVisible = maxVisible
        self.selectedTags = selectedTags
        self.onTagTap = onTagTap
    }
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Array(tags.prefix(maxVisible)), id: \.self) { tag in
                TagBadge(
                    tag: tag,
                    isSelected: selectedTags.contains(tag),
                    onTap: onTagTap != nil ? { onTagTap?(tag) } : nil
                )
            }
            
            if tags.count > maxVisible {
                Text("+\(tags.count - maxVisible)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeManager.colors.textSecondary)
                    .padding(.horizontal, Spacing.xs + 2)
                    .padding(.vertical, Spacing.xs)
                    .background(themeManager.colors.bgSecondary)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Reading Status Badge

struct ReadingStatusBadge: View {
    let status: ReadingStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10, weight: .medium))
            Text(status.displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(Color(hex: status.color))
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Color(hex: status.color).opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Badge View (for notifications)

struct BadgeView: View {
    let count: Int
    let color: Color
    
    init(count: Int, color: Color = .red) {
        self.count = count
        self.color = color
    }
    
    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, count > 9 ? 6 : 4)
                .padding(.vertical, 2)
                .background(color)
                .clipShape(Capsule())
                .frame(minWidth: 18)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 8) {
            TagBadge(tag: "Technology")
            TagBadge(tag: "Swift", isSelected: true)
            TagBadge(tag: "iOS")
        }
        .environmentObject(ThemeManager.shared)
        
        TagListView(
            tags: ["Swift", "iOS", "SwiftUI", "Combine", "Xcode"],
            maxVisible: 3
        )
        .environmentObject(ThemeManager.shared)
        
        HStack(spacing: 12) {
            ReadingStatusBadge(status: .unread)
            ReadingStatusBadge(status: .reading)
            ReadingStatusBadge(status: .completed)
        }
        
        HStack(spacing: 12) {
            BadgeView(count: 3)
            BadgeView(count: 12)
            BadgeView(count: 150)
        }
    }
    .padding()
}
