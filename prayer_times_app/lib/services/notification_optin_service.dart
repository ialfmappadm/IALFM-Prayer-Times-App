// lib/services/notification_optin_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationOptInService {
  static final FirebaseMessaging _fm = FirebaseMessaging.instance;

  /// Returns the OS-level authorization state for notifications.
  static Future<NotificationSettings> getStatus() {
    return _fm.getNotificationSettings();
  }

  /// Requests permission (iOS + Android 13+).
  static Future<NotificationSettings> requestPermission() async {
    final settings = await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: false,
    );
    // Example topic subscription once authorized
    if (isAuthorized(settings)) {
      try {
        await _fm.subscribeToTopic('allUsers');
      } catch (_) {/* ignore */}
    }
    return settings;
  }

  static bool isAuthorized(NotificationSettings s) =>
      s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;

  /// Opens the app's OS settings page (user can enable notifications there).
  static Future<void> openOSSettings() => openAppSettings();
}