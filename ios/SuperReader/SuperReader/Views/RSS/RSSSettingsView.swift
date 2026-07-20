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
                    Picker("Intervallo", selection: selection) {
                        ForEach(RSSRefreshInterval.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                } header: {
                    Text("Aggiornamento automatico")
                } footer: {
                    Text("Quando rientri nel tab RSS, i feed vengono aggiornati solo se è trascorso questo intervallo dall'ultimo aggiornamento. \"Subito\" aggiorna sempre, \"Mai\" disabilita l'aggiornamento automatico. Il pulsante di aggiornamento manuale resta sempre attivo.")
                }
            }
            .navigationTitle("Impostazioni RSS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }
                }
            }
        }
    }
}
