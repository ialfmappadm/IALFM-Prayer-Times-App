import UIKit
import Flutter
import WatchConnectivity
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // 0) Start WatchConnectivity (iOS side)
    WCPhoneSessionManager.shared.start()

    // 1) Safely unwrap Flutter root
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // 2) Optional: quick debug ping a few seconds after launch (remove when done)
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
      WCPhoneSessionManager.shared.sendPing()
    }

    // 3) Notifications (permission + register APNs)
    UNUserNotificationCenter.current().delegate = self
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
      if let error = error {
        print("🔔 Notification authorization error:", error)
      } else {
        print("🔔 Notification authorization granted:", granted)
      }
    }
    application.registerForRemoteNotifications()

    // 4) MethodChannel for watch connectivity helpers
    let ch = FlutterMethodChannel(name: "wc", binaryMessenger: controller.binaryMessenger)
    ch.setMethodCallHandler { call, result in
      switch call.method {

      case "send_ping":
        WCPhoneSessionManager.shared.sendPing()
        result("ok")

      case "wc_push_next_prayer":
        if let m = call.arguments as? [String: Any],
           let next = m["next"] as? String,
           let ts = m["targetTs"] as? Double {
          WCPhoneSessionManager.shared.pushNextPrayer(next: next, targetTs: ts)
        }
        result("ok")

      case "wc_push_day_times":
        if let map = call.arguments as? [String: String] {
          WCPhoneSessionManager.shared.pushDayTimes(map)
        }
        result("ok")

      case "wc_push_announcements":
        if let arr = call.arguments as? [[String: Any]] {
          WCPhoneSessionManager.shared.pushAnnouncements(arr)
        }
        result("ok")

      case "wc_transfer_prayer_json":
        if let path = (call.arguments as? [String:String])?["path"] {
          WCPhoneSessionManager.shared.transferPrayerJSON(fileURL: URL(fileURLWithPath: path))
        }
        result("ok")

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 5) Register Flutter plugins and return
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: Foreground presentation (iOS 10+)
  @available(iOS 10.0, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .list, .sound])
  }

  // MARK: User tapped notification
  @available(iOS 10.0, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
    completionHandler()
  }
}