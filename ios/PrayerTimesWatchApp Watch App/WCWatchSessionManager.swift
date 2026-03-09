#if os(watchOS)
import Foundation
import WatchConnectivity

final class WCWatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WCWatchSessionManager()
    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        print("[watch] WCSession activate() called")
    }

    // ---- TEST helpers ----
    func sendPing() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "ping"],
            replyHandler: { reply in
                print("[watch] got reply:", reply)
            },
            errorHandler: { err in
                print("[watch] send error:", err)
            }
        )
    }

    func pushApplicationContext(_ ctx: [String: Any]) {
        try? WCSession.default.updateApplicationContext(ctx)
    }

    func queueUserInfo(_ m: [String: Any]) {
        WCSession.default.transferUserInfo(m)
    }

    // ---- SETTINGS -> phone ----
    func sendSettings(_ settings: [String: Any]) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["type": "settings_update", "settings": settings],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    // MARK: WCSessionDelegate
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print("[watch] activationDidCompleteWith:", activationState.rawValue, "error:", String(describing: error))
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("[watch] reachability:", session.isReachable)
    }

    // Application Context (authoritative snapshot from phone)
    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String : Any]) {
        if applicationContext.isEmpty { return }
        DispatchQueue.main.async {
            let s = AppState.shared
            if let next = applicationContext["nextPrayer"] as? String { s.nextPrayer = next }
            if let ts = applicationContext["targetTs"] as? Double { s.targetTs = ts }

            if let settings = applicationContext["settings"] as? [String: Any] {
                s.alertsEnabled = settings["alertsEnabled"] as? Bool ?? s.alertsEnabled
                s.hapticsEnabled = settings["hapticsEnabled"] as? Bool ?? s.hapticsEnabled
                s.theme = settings["theme"] as? String ?? s.theme
                s.textScale = settings["textScale"] as? Double ?? s.textScale
                s.use24h = settings["use24h"] as? Bool ?? s.use24h
            }
            if let arr = applicationContext["announcements"] as? [[String: Any]] {
                s.announcements = arr.map { m in
                    let id = (m["id"] as? String) ?? UUID().uuidString
                    let title = (m["title"] as? String) ?? ""
                    let text  = (m["text"]  as? String) ?? ""
                    let whenStr = (m["when"] as? String) ?? ""
                    let when = ISO8601DateFormatter().date(from: whenStr)
                    return AppState.Ann(id: id, title: title, text: text, when: when)
                }
            }
        }
    }

    // File transfer: yearly JSON
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let kind = file.metadata?["kind"] as? String, kind == "prayer_json" else { return }
        let dest = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(file.fileURL.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: file.fileURL, to: dest)
        print("[watch] stored prayer JSON:", dest.lastPathComponent)
    }
}
#endif