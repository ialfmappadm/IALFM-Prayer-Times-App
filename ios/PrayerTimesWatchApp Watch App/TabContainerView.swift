#if os(watchOS)
import SwiftUI

enum WTab: Int { case prayer = 0, notifications, settings }

struct TabContainerView: View {
    @State private var tab: WTab = .prayer

    var body: some View {
        ZStack {
            Group {
                switch tab {
                case .prayer:         PrayerPage()
                case .notifications:  NotificationsPage()
                case .settings:       SettingsPage()
                }
            }

            VStack {
                Spacer(minLength: 0)
                HStack(spacing: 18) {
                    TabButton(symbol: "clock.badge.checkmark", label: "Prayer", isOn: tab == .prayer) { tab = .prayer }
                    TabButton(symbol: "bell.badge",           label: "Alerts", isOn: tab == .notifications) { tab = .notifications }
                    TabButton(symbol: "gear",                 label: "Settings", isOn: tab == .settings) { tab = .settings }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 6)
            }
        }
    }
}

private struct TabButton: View {
    let symbol: String, label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .imageScale(.small)
                    .symbolVariant(isOn ? .fill : .none)
                Text(label).font(.caption2)
            }
            .foregroundStyle(isOn ? .tint : .secondary)
        }
        .buttonStyle(.plain)
    }
}
#endif
