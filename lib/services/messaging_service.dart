// lib/services/messaging_service.dart
//
// Centralizes Firebase Cloud Messaging wiring:
//  - Background handler (refresh schedule if requested via data message)
//  - Foreground permission request & topic subscribe (deferred)
//  - Foreground "nudge" callbacks for announcements tab red-dot & deep-link
//
// Usage from main.dart / UI:
//   MessagingService.instance.configureBackgroundHandler();
//   MessagingService.instance.initDeferred();
//   MessagingService.instance.bindAnnouncementNudges(
//       onNewNudge: () => setState(() => hasNewAnnouncement = true),
//       onOpenNudge: () => setState(() { _index = 1; hasNewAnnouncement = false; }),
//   );

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../firebase_options.dart';
import '../prayer_times_firebase.dart';


class MessagingService {
  MessagingService._();
  static final instance = MessagingService._();

  bool _boundAnnouncements = false;

  /// Register the @pragma background handler.
  /// Call once after Firebase.initializeApp in main().
  void configureBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Request notification permission and subscribe to topics (deferred).
  /// Safe to call multiple times; it guards internally.
  Future<void> initDeferred() async {
    // Foreground presentation options (iOS)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // Defer like your previous code (~1.2s) to avoid jank on first frame.
    unawaited(Future<void>.delayed(const Duration(milliseconds: 1200)).then((_) async {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true, badge: true, sound: true, provisional: false,
        );
        debugPrint('FCM permission (deferred): ${settings.authorizationStatus}');
        await FirebaseMessaging.instance.subscribeToTopic('allUsers');
      } catch (e, st) {
        debugPrint('Deferred FCM setup error: $e\n$st');
      }
    }));
  }

  /// Wire announcement nudges (dot + deep-link to the tab).
  /// Provide closures that modify the caller's state.
  void bindAnnouncementNudges({
    required VoidCallback onNewNudge,
    required VoidCallback onOpenNudge,
  }) {
    if (_boundAnnouncements) return;
    _boundAnnouncements = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['newAnnouncement'] == 'true') {
        onNewNudge();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage m) {
      if (m.data['newAnnouncement'] == 'true') {
        onOpenNudge();
      }
    });

    // Handle "cold start" deep link
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m?.data['newAnnouncement'] == 'true') {
        onOpenNudge();
      }
    });
  }
}

/// Top-level background handler: required entry-point for Android/iOS.
/// It initializes Firebase and refreshes the local schedule when data message
/// contains { updatePrayerTimes: "true", year: "2026" }.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  final repo = PrayerTimesRepository();
  final shouldRefresh = message.data['updatePrayerTimes'] == 'true';
  final yearStr = message.data['year'];
  final year = (yearStr != null) ? int.tryParse(yearStr) : null;

  if (shouldRefresh) {
    await repo.refreshFromFirebase(year: year);
  }
}