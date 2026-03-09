#if os(watchOS)
import SwiftUI
import WatchKit

struct SettingsPage: View {
    @ObservedObject private var app = AppState.shared

    private func send() {
        if app.hapticsEnabled { WKInterfaceDevice.current().play(.success) }
        WCWatchSessionManager.shared.sendSettings([
            "alertsEnabled": app.alertsEnabled,
            "hapticsEnabled": app.hapticsEnabled,
            "theme": app.theme,
            "textScale": app.textScale,
            "use24h": app.use24h
        ])
    }

    var body: some View {
        Form {
            Toggle("Alerts", isOn: Binding(
                get: { app.alertsEnabled }, set: { app.alertsEnabled = $0; send() }
            ))
            Toggle("Haptics", isOn: Binding(
                get: { app.hapticsEnabled }, set: { app.hapticsEnabled = $0; send() }
            ))
            Picker("Theme", selection: Binding(
                get: { app.theme }, set: { app.theme = $0; send() }
            )) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            HStack {
                Text("Text size")
                Slider(value: Binding(
                    get: { app.textScale }, set: { app.textScale = $0; send() }
                ), in: 0.8...1.4, step: 0.05)
            }
            Toggle("24‑hour time", isOn: Binding(
                get: { app.use24h }, set: { app.use24h = $0; send() }
            ))
        }
        .navigationTitle("Settings")
    }
}
#endif