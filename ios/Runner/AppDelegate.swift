import UIKit
import Flutter
import Firebase            // ← keep if you want native configure here
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate { // ← removed redundant protocol

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // 1) Configure Firebase (optional if you already call Firebase.initializeApp() in Dart)
    FirebaseApp.configure()

    // 2) iOS 10+: Ask for permission & set notification center delegate
    UNUserNotificationCenter.current().delegate = self
    let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
      if let error = error {
        print("🔔 Notification authorization error: \(error)")
      } else {
        print("🔔 Notification authorization granted: \(granted)")
      }
    }

    // 3) Register with APNs to get device token
    application.registerForRemoteNotifications()

    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    // Call super last
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 4) Receive APNs device token (optional but useful to debug)
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // If you don’t use FirebaseMessaging directly here, leaving this empty is fine.
    // FlutterFire’s Messaging plugin will map APNs token to FCM automatically via method swizzling
    // (unless you explicitly disabled swizzling).
    // Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // 5) Handle foreground notifications
  @available(iOS 10.0, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .list, .sound])
  }

  // 6) Handle user tapping a notification
  @available(iOS 10.0, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
    completionHandler()
  }
}