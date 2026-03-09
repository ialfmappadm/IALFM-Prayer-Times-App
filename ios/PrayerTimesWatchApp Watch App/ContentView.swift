#if os(watchOS)
import SwiftUI

struct ContentView: View {
    @State private var log: [String] = []

    var body: some View {
        NavigationStack {
            List {
                NavigationLink { PrayerPage() }       label: { Label("Prayer", systemImage: "clock.badge.checkmark") }
                NavigationLink { NotificationsPage() } label: { Label("Notifications", systemImage: "bell.badge") }
                NavigationLink { SettingsPage() }      label: { Label("Settings", systemImage: "gear") }

                Section("Connectivity Test") {
                    Button {
                        WCWatchSessionManager.shared.sendPing()
                        append("Sent ping → iPhone")
                    } label: { Label("Ping iPhone", systemImage: "arrow.up.right.circle.fill") }
                }

                if !log.isEmpty {
                    Section("Log") { ForEach(Array(log.enumerated()), id:\.offset) { _, t in Text(t).font(.footnote) } }
                }
            }
            .listStyle(.carousel)
            .navigationTitle("Prayer Times")
        }
    }
    private func append(_ s: String) { log.insert(s, at: 0); if log.count > 12 { _ = log.popLast() } }
}
#endif