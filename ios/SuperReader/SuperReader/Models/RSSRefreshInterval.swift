import Foundation

enum RSSRefreshInterval: String, CaseIterable, Identifiable {
    case immediate
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case fiveHours
    case never

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .immediate: return "Subito"
        case .fifteenMinutes: return "15 minuti"
        case .thirtyMinutes: return "30 minuti"
        case .oneHour: return "1 ora"
        case .twoHours: return "2 ore"
        case .fiveHours: return "5 ore"
        case .never: return "Mai"
        }
    }

    /// Seconds that must pass since the last refresh before auto-refresh fires again.
    /// `0` means always refresh on appear. `nil` disables auto-refresh entirely.
    var seconds: TimeInterval? {
        switch self {
        case .immediate: return 0
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fiveHours: return 5 * 60 * 60
        case .never: return nil
        }
    }
}
