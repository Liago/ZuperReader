import SwiftUI

struct RSSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    @AppStorage(RSSViewModel.autoRefreshIntervalKey) private var rawInterval: String = RSSRefreshInterval.fifteenMinutes.rawValue

    private var selection: Binding<RSSRefreshInterval> {
        Binding(
            get: { RSSRefreshInterval(rawValue: rawInterval) ?? .fifteenMinutes },
            set: { rawInterval = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Interval", selection: selection) {
                        ForEach(RSSRefreshInterval.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                } header: {
                    Text("Automatic refresh")
                } footer: {
                    Text("When you return to the Feeds tab, feeds only refresh if this interval has passed since the last update. \"Immediately\" always refreshes, \"Never\" disables auto-refresh. The manual refresh button always stays active.")
                }
            }
            .navigationTitle("Feed Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
