import SwiftUI

// MARK: - Feed / Library content components
//
// I mattoni condivisi tra la vista di un singolo canale feed (design 06b,
// docs/revamp-ios/feed-channel/README.md) e la lista della Libreria in
// homepage, così che le due schermate parlino esattamente la stessa lingua:
//
// - articolo in evidenza con copertina 168pt (radius 26);
// - righe con miniatura 78pt e angoli a 22pt;
// - sotto il titolo *una* sola informazione — snippet oppure barra di
//   avanzamento — mai entrambe;
// - separatore rientrato di 92pt (miniatura + gap).
//
// I componenti non conoscono né `Article` né `RSSArticle`: ricevono valori già
// risolti, così la stessa riga serve entrambe le liste.

// MARK: - Item state

/// Stato di lettura di una riga: governa il punto colorato, il colore del
/// titolo e cosa compare sotto di esso.
enum FeedItemState: Equatable {
    /// Non letto — punto `accent-2`, titolo pieno, snippet sotto.
    case unread
    /// In corso — punto `accent`, barra di avanzamento al posto dello snippet.
    case reading(progress: Double)
    /// Letto — check muted, titolo muted, niente snippet.
    case read

    var isRead: Bool { self == .read }

    func dotColor(_ colors: ThemeColors) -> Color {
        switch self {
        case .unread: return colors.accent2
        case .reading: return colors.accent
        case .read: return colors.muted
        }
    }

    /// Frazione 0…1 della barra, o `nil` se la riga non mostra avanzamento.
    var progressFraction: Double? {
        guard case let .reading(progress) = self else { return nil }
        return min(max(progress, 0), 1)
    }
}

// MARK: - State dot

/// Punto 6pt di stato, o il check per gli articoli letti (design 06b: "niente
/// punto ma un check 13pt muted").
struct FeedStateIndicator: View {
    let state: FeedItemState
    var size: CGFloat = 6

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Group {
            if state.isRead {
                Image(systemName: "checkmark")
                    .font(Typography.symbol(13, weight: .bold))
                    .foregroundColor(themeManager.colors.muted)
            } else {
                Circle()
                    .fill(state.dotColor(themeManager.colors))
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Media placeholder tint

/// Le due tinte alternate dei segnaposto immagine del design (accent e
/// accent-2), più la variante neutra `sink` per gli articoli già letti.
enum MediaTint {
    case accent
    case accent2
    case neutral

    /// Alterna accent / accent-2 lungo la lista, come nel mockup.
    static func alternating(_ index: Int) -> MediaTint {
        index.isMultiple(of: 2) ? .accent2 : .neutral
    }

    func fill(_ colors: ThemeColors) -> Color {
        switch self {
        case .accent: return colors.accent200
        case .accent2: return colors.accent2_200
        case .neutral: return colors.sink
        }
    }

    func glyph(_ colors: ThemeColors) -> Color {
        switch self {
        case .accent: return colors.accent800.opacity(0.5)
        case .accent2: return colors.accent2_800.opacity(0.5)
        case .neutral: return colors.text.opacity(0.35)
        }
    }
}

// MARK: - Media block

/// Blocco immagine con segnaposto tinto: l'immagine riempie lo slot
/// (`scaledToFill` + clip sul radius, nessun bordo), il segnaposto è una tinta
/// piatta con il glifo immagine al centro.
struct FeedMediaBlock: View {
    let imageUrl: String?
    let cornerRadius: CGFloat
    var tint: MediaTint = .accent
    var glyphSize: CGFloat = 22

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            tint.fill(themeManager.colors)

            if let imageUrl, !imageUrl.isEmpty {
                AsyncImageView(url: imageUrl, cornerRadius: 0)
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .font(Typography.symbol(glyphSize, weight: .regular))
                    .foregroundColor(tint.glyph(themeManager.colors))
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Progress track

/// Barra di avanzamento 2pt, track `line`, fill `accent` (design 06b).
struct FeedProgressTrack: View {
    let fraction: Double
    var height: CGFloat = 2

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(themeManager.colors.line)
                Capsule()
                    .fill(themeManager.colors.accent)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Featured article

/// Articolo in evidenza: copertina 168pt radius 26, riga meta con data in
/// maiuscoletto e tempo di lettura a destra, titolo 19pt/800 su 3 righe,
/// snippet su 2 righe.
struct FeaturedArticleCard: View {
    let imageUrl: String?
    let state: FeedItemState
    /// Data già formattata — viene resa in maiuscolo dal componente.
    let dateLabel: String?
    let readTimeLabel: String?
    let title: String
    let snippet: String?
    var tint: MediaTint = .accent
    /// `false` quando la sorgente non pubblica mai immagini: la copertina
    /// sparisce invece di ripetere un segnaposto vuoto (design 06b · Note).
    var showsCover: Bool = true

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsCover {
                FeedMediaBlock(
                    imageUrl: imageUrl,
                    cornerRadius: CornerRadius.featuredCover,
                    tint: tint,
                    glyphSize: 30
                )
                .frame(height: Spacing.featuredCoverHeight)
                .padding(.bottom, 12)
            }

            HStack(spacing: 7) {
                FeedStateIndicator(state: state)

                if let dateLabel {
                    Text(dateLabel.uppercased())
                        .font(Typography.featuredMeta)
                        .tracking(0.72) // .06em su 12pt
                        .foregroundColor(themeManager.colors.muted)
                }

                Spacer(minLength: 8)

                if let readTimeLabel {
                    Text(readTimeLabel)
                        .font(Typography.rowMeta)
                        .foregroundColor(themeManager.colors.muted)
                }
            }
            .padding(.bottom, 6)

            Text(title)
                .font(Typography.featuredTitle)
                .tracking(-0.19) // −.01em su 19pt
                .lineSpacing(1.5) // line-height 1.28
                .foregroundColor(state.isRead ? themeManager.colors.muted : themeManager.colors.text)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 6)

            if let snippet, !snippet.isEmpty, !state.isRead {
                Text(snippet)
                    .font(Typography.featuredSnippet)
                    .lineSpacing(4) // line-height 1.5
                    .foregroundColor(themeManager.colors.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - List row

/// Riga di lista del canale / della Libreria: miniatura 78pt radius 22, riga
/// meta, titolo su 2 righe e — sotto — snippet *oppure* barra di avanzamento.
struct FeedArticleRow: View {
    let imageUrl: String?
    let state: FeedItemState
    let metaLabel: String?
    let readTimeLabel: String?
    let title: String
    let snippet: String?
    var tint: MediaTint = .accent2
    /// `false` quando la sorgente non pubblica mai immagini: la riga collassa a
    /// testo a piena larghezza (design 06b · Note).
    var showsThumbnail: Bool = true
    /// Marker opzionale accanto alla meta (es. il bookmark "salvato in Libreria").
    var trailingBadge: AnyView?

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if showsThumbnail {
                FeedMediaBlock(
                    imageUrl: imageUrl,
                    cornerRadius: CornerRadius.feedThumbnail,
                    tint: state.isRead ? .neutral : tint
                )
                .frame(width: Spacing.feedThumbnailSize, height: Spacing.feedThumbnailSize)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    FeedStateIndicator(state: state)

                    if let metaLabel {
                        Text(metaLabel)
                            .font(Typography.rowMeta)
                            .foregroundColor(themeManager.colors.muted)
                            .lineLimit(1)
                    }

                    if let trailingBadge {
                        trailingBadge
                    }

                    Spacer(minLength: 8)

                    if let readTimeLabel {
                        Text(readTimeLabel)
                            .font(Typography.rowMeta)
                            .foregroundColor(themeManager.colors.muted)
                    }
                }
                .padding(.bottom, 5)

                Text(title)
                    .font(Typography.listRowTitle)
                    .lineSpacing(2.3) // line-height 1.35
                    .foregroundColor(state.isRead ? themeManager.colors.muted : themeManager.colors.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                // Una sola informazione sotto il titolo: la barra se l'articolo
                // è in corso, altrimenti lo snippet; niente per i letti.
                if let fraction = state.progressFraction {
                    FeedProgressTrack(fraction: fraction)
                        .padding(.top, 6)
                } else if let snippet, !snippet.isEmpty, !state.isRead {
                    Text(snippet)
                        .font(Typography.rowSnippet)
                        .foregroundColor(themeManager.colors.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
        .contentShape(Rectangle())
    }
}

// MARK: - Row separator alignment

extension View {
    /// Rientra il separatore di `List` di 92pt (miniatura 78 + gap 14), come
    /// nel design, e lo tinge con il token `line`. Con `inset: 0` il separatore
    /// torna a piena larghezza per le righe senza miniatura.
    func feedRowSeparator(_ color: Color, inset: CGFloat = Spacing.rowSeparatorInset) -> some View {
        self
            .alignmentGuide(.listRowSeparatorLeading) { _ in inset }
            .listRowSeparatorTint(color)
    }
}

// MARK: - Filter pill

/// Pill dei filtri: attiva = fill `text` con label `page`, inattiva = bordo
/// 1pt `line`. Il punto colorato a sinistra è opzionale.
struct FeedFilterPill: View {
    let title: String
    var dotColor: Color?
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 6, height: 6)
                }
                Text(title)
                    .font(Typography.filterPill(selected: isSelected))
            }
            .foregroundColor(isSelected ? themeManager.colors.page : themeManager.colors.text)
            .padding(.horizontal, 15)
            .padding(.vertical, 7)
            .background(isSelected ? themeManager.colors.text : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : themeManager.colors.line, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .minimumTapTarget()
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Accent action pill

/// Pill piena `accent` con glifo + label (es. "Mark all read").
struct FeedActionPill: View {
    let title: String
    let systemImage: String
    var isBusy: Bool = false
    let action: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isBusy {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(themeManager.colors.page)
                } else {
                    Image(systemName: systemImage)
                        .font(Typography.symbol(13, weight: .heavy))
                }
                Text(title)
                    .font(Typography.figtree(13, weight: .bold, relativeTo: .footnote))
            }
            .foregroundColor(themeManager.colors.page)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(themeManager.colors.accent)
            .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .minimumTapTarget()
    }
}

// MARK: - Undo toast

/// Toast con azione di annullamento, per le azioni distruttive "soffici" come
/// "segna tutto come letto" (design 06b · "richiede undo in toast").
struct UndoToast: View {
    let message: String
    let undoTitle: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(Typography.figtree(14, weight: .semibold))
                .foregroundColor(themeManager.colors.text)
                .lineLimit(2)

            Button(action: onUndo) {
                Text(undoTitle)
                    .font(Typography.figtree(14, weight: .bold))
                    .foregroundColor(themeManager.colors.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(themeManager.colors.card)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(themeManager.colors.line, lineWidth: 1))
        .shadow(color: AppShadows.card.color, radius: 8, x: 0, y: 4)
        .padding(.horizontal, Spacing.screenHorizontal)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Dismiss", onDismiss)
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

// MARK: - Relative date helpers

enum FeedDateFormat {
    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    /// "updated 4 min ago" — la coda del sottotitolo dell'header canale.
    static func relativeString(from date: Date) -> String {
        relative.localizedString(for: date, relativeTo: Date())
    }

    /// "Today, 01:08" / "Yesterday, 22:31" / "12 Sep, 09:30" — la meta di riga.
    static func rowLabel(from date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) {
            return String(localized: "Today") + ", " + time
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday") + ", " + time
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 7) {
                FeedFilterPill(title: "Unread", dotColor: Color(hex: "#7A8A5E"), isSelected: true) {}
                FeedFilterPill(title: "All", isSelected: false) {}
                Spacer()
                FeedActionPill(title: "Mark all read", systemImage: "checkmark") {}
            }

            FeaturedArticleCard(
                imageUrl: nil,
                state: .unread,
                dateLabel: "Today, 01:08",
                readTimeLabel: "6 min",
                title: "The Quantified Scientist tests the Apple Watch Series 12's new heart rate sensor",
                snippet: "Rob ter Horst compares the new sensor against a chest strap across a week of workouts."
            )

            FeedArticleRow(
                imageUrl: nil,
                state: .unread,
                metaLabel: "Yesterday, 22:31",
                readTimeLabel: "3 min",
                title: "iOS 27 and iPadOS 27 expand language support for Dictionary, QuickType",
                snippet: "More than 30 new languages land in the Feature Availability page."
            )

            FeedArticleRow(
                imageUrl: nil,
                state: .reading(progress: 0.38),
                metaLabel: "Yesterday, 22:05",
                readTimeLabel: "2 min",
                title: "Download the iPhone Duo's official light and dark wallpapers",
                snippet: nil,
                tint: .neutral
            )
        }
        .padding(Spacing.screenHorizontal)
    }
    .background(Color(hex: "#F5EAD8"))
    .environmentObject(ThemeManager.shared)
}
