import Foundation
import WatchConnectivity

final class WCPhoneSessionManager: NSObject, WCSessionDelegate {
    static let shared = WCPhoneSessionManager()
    private override init() { super.init() }

    // Activate WCSession on iOS
    func start() {
        guard WCSession.isSupported() else {
            print("[iOS] WCSession not supported")
            return
        }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        print("[iOS] WCSession activate() called")
    }

    // Optional debug helper (iOS -> watch)
    func sendPing() {
        guard WCSession.default.isReachable else {
            print("[iOS] watch not reachable (isReachable=false)")
            return
        }
        WCSession.default.sendMessage(
            ["type": "ping_from_ios", "at": Date().timeIntervalSince1970],
            replyHandler: { reply in print("[iOS] got reply:", reply) },
            errorHandler: { error in print("[iOS] send error:", error) }
        )
    }

    // ---------- PHONE -> WATCH state push ----------

    /// Push the next-prayer label and its target epoch timestamp (seconds).
    func pushNextPrayer(next: String, targetTs: Double) {
        var ctx = WCSession.default.receivedApplicationContext
        ctx["nextPrayer"] = next
        ctx["targetTs"] = targetTs
        do {
            try WCSession.default.updateApplicationContext(ctx)
            print("[iOS] pushed nextPrayer:", next, targetTs)
        } catch {
            print("[iOS] updateApplicationContext error:", error)
        }
    }

    /// Push today's prayer times map, e.g. {"Fajr":"05:34","Dhuhr":"01:24",...}
    func pushDayTimes(_ dayTimes: [String: String]) {
        var ctx = WCSession.default.receivedApplicationContext
        ctx["dayTimes"] = dayTimes
        do {
            try WCSession.default.updateApplicationContext(ctx)
            print("[iOS] pushed dayTimes:", dayTimes.count)
        } catch {
            print("[iOS] dayTimes push error:", error)
        }
    }

    /// Push condensed announcements list: [{"id","title","text","when"}, ...]
    func pushAnnouncements(_ items: [[String: Any]]) {
        var ctx = WCSession.default.receivedApplicationContext
        ctx["announcements"] = items
        do {
            try WCSession.default.updateApplicationContext(ctx)
            print("[iOS] pushed announcements: \(items.count)")
        } catch {
            print("[iOS] announcements push error:", error)
        }
    }

    /// Transfer yearly prayer-times JSON to the watch (saved under watch Documents/)
    func transferPrayerJSON(fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[iOS] transferPrayerJSON: file not found:", fileURL.path)
            return
        }
        WCSession.default.transferFile(fileURL, metadata: ["kind": "prayer_json"])
        print("[iOS] transferred file:", fileURL.lastPathComponent)
    }

    // ---------- WATCH -> PHONE handlers (optional) ----------

    private func applySettingsFromWatch(_ settings: [String: Any]) {
        // TODO: persist your settings & reschedule alerts if needed (alertsEnabled/use24h/etc.)
        var ctx = WCSession.default.receivedApplicationContext
        ctx["settings"] = settings
        try? WCSession.default.updateApplicationContext(ctx)
        print("[iOS] settings updated & mirrored:", settings)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("[iOS] activationDidCompleteWith:", activationState.rawValue, "error:", String(describing: error))
    }

    func sessionDidBecomeInactive(_ session: WCSession) { print("[iOS] sessionDidBecomeInactive") }

    func sessionDidDeactivate(_ session: WCSession) {
        print("[iOS] sessionDidDeactivate -> reactivate")
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[iOS] reachability:", session.isReachable)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String : Any],
                 replyHandler: @escaping ([String : Any]) -> Void) {
        print("[iOS] didReceiveMessage:", message)
        if let type = message["type"] as? String {
            switch type {
            case "settings_update":
                if let s = message["settings"] as? [String: Any] {
                    applySettingsFromWatch(s)
                }
                replyHandler(["ok": true])

            case "ping":
                replyHandler(["type": "pong", "from": "iOS", "at": Date().timeIntervalSince1970])

            default:
                replyHandler(["ok": true])
            }
        } else {
            replyHandler(["ok": true])
        }
    }
}