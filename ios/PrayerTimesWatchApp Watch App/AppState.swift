#if os(watchOS)
import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    private init() {}

    // PRAYER (landing)
    @Published var nextPrayer: String = "—"
    @Published var targetTs: TimeInterval = 0

    // Today's times (comes from iOS via applicationContext["dayTimes"])
    // Example: ["Fajr":"05:34","Dhuhr":"01:24","Asr":"04:52","Maghrib":"06:48","Isha":"08:04"]
    @Published var dayTimes: [String: String] = [:]

    // ANNOUNCEMENTS (compact)
    struct Ann: Identifiable { let id: String; let title: String; let text: String; let when: Date? }
    @Published var announcements: [Ann] = []

    // SETTINGS (mirrored from iPhone)
    @Published var alertsEnabled: Bool = true
    @Published var hapticsEnabled: Bool = true
    @Published var theme: String = "system"   // system|light|dark
    @Published var textScale: Double = 1.0    // 0.8...1.4
    @Published var use24h: Bool = true
}
#endif