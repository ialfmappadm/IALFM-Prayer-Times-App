// PrayerTimesWatchAppApp.swift
#if os(watchOS)
import SwiftUI
import WatchConnectivity

@main
struct PrayerTimesWatchAppApp: App {
    init() {
        WCWatchSessionManager.shared.activate()  // now compiles
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
#endif