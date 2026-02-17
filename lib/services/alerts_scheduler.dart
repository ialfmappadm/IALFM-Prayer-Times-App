// lib/services/alerts_scheduler.dart
//
// Schedules local notifications for:
// • Prayer Alerts: Adhan (at time) & Iqamah (~5 minutes before) for the current day
// • Jumu'ah Reminder: Fridays 12:30 PM local time
// Uses flutter_local_notifications + timezone (tz).
//
// Key points:
// • Creates a HIGH-importance channel (heads-up popup on Android 8+) [ref: channels & importance]
// • Requests Android 13+ runtime notification permission via the plugin [ref: POST_NOTIFICATIONS runtime]
// • Schedules with EXACT first, then falls back to INEXACT if exact alarms are denied on Android 14+
//   (so you don't need USE_EXACT_ALARM in the manifest). [ref: exact-alarm restriction]
//
// Reuse as-is with your existing call sites.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class AlertsScheduler {
  AlertsScheduler._();
  static final AlertsScheduler instance = AlertsScheduler._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'ialfm_alerts';
  static const String _channelName = 'Prayer & Jumu’ah Alerts';
  static const String _channelDesc = 'Adhan/Iqamah alerts and Friday Jumu’ah reminder';

  bool _initialized = false;

  /// Initialize local notifications and create the Android channel.
  /// [androidSmallIcon] must exist in res/drawable as a monochrome icon (e.g., ic_stat_bell).
  Future<void> init({String androidSmallIcon = 'ic_stat_bell'}) async {
    if (_initialized) return;

    final androidInit = AndroidInitializationSettings(androidSmallIcon);
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    final initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (r) {
        if (kDebugMode) {
          debugPrint('[AlertsScheduler] tapped. payload=${r.payload}');
        }
      },
    );

    // Create a High-importance channel to enable heads-up popups on Android 8+.
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Request iOS/Android 13+ runtime notification permission.
  Future<void> requestPermissions() async {
    await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission(); // Android 13+
    await _fln
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> cancelAll() async => _fln.cancelAll();

  /// Cancel all schedules for a specific day (by ID pattern).
  /// IDs: yyyymmdd * 100 + slot (0..N).
  Future<void> cancelAllForDate(DateTime dateLocal) async {
    final dayBase = _yyyymmdd(dateLocal);
    for (int slot = 0; slot < 50; slot++) {
      await _fln.cancel(_idFor(dayBase, slot));
    }
  }

  /// DEV: dump all pending notifications (IDs, titles, payloads) for audit.
  Future<List<PendingNotificationRequest>> dumpPending({bool printLog = true}) async {
    final list = await _fln.pendingNotificationRequests();
    if (printLog) {
      debugPrint('[AlertsScheduler] Pending notifications (${list.length}):');
      for (final p in list) {
        debugPrint('  • id=${p.id} title="${p.title}" payload="${p.payload}"');
      }
    }
    return list;
  }

  /// DEV: Android-only quick check if notifications are enabled at the OS level.
  Future<bool?> areNotificationsEnabledAndroid() async {
    return await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
  }

  /// Schedule Adhan & Iqamah alerts for [dateLocal]. Null inputs are skipped.
  Future<void> schedulePrayerAlertsForDay({
    required DateTime dateLocal,
    // Adhan times
    DateTime? fajrAdhan,
    DateTime? dhuhrAdhan,
    DateTime? asrAdhan,
    DateTime? maghribAdhan,
    DateTime? ishaAdhan,
    // Iqamah times
    DateTime? fajrIqamah,
    DateTime? dhuhrIqamah,
    DateTime? asrIqamah,
    DateTime? maghribIqamah,
    DateTime? ishaIqamah,
    bool adhanEnabled = true,
    bool iqamahEnabled = true,
  }) async {
    assert(_initialized, 'AlertsScheduler.init() must be called first');

    // Clear prior schedules for this day to avoid duplicates.
    await cancelAllForDate(dateLocal);

    final base = _yyyymmdd(dateLocal);
    int slot = 0;

    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: 'IALFM Alert',
    );
    const ios = DarwinNotificationDetails(presentAlert: true, presentSound: true);
    const nDetails = NotificationDetails(android: android, iOS: ios);

    // helper to schedule if time is in future, with an optional offset
    Future<void> scheduleWithOffset({
      required String title,
      required String body,
      required DateTime? when,
      required Duration offset,
      required int id,
      String payload = 'prayer_alert',
    }) async {
      if (when == null) return;
      final alertAt = when.add(offset);
      if (alertAt.isBefore(DateTime.now())) return;
      final tzTime = tz.TZDateTime.from(alertAt, tz.local);

      // DEV log
      debugPrint('[AlertsScheduler] scheduling => '
          'title="$title" body="$body" at=${alertAt.toLocal()} (tz: $tzTime) id=$id');

      await _safeZonedSchedule(
        id: id,
        title: title,
        body: body,
        when: tzTime,
        details: nDetails,
        payload: payload,
      );
    }

    // Adhan (at time)
    if (adhanEnabled) {
      await scheduleWithOffset(
        title: 'Adhan Reminder',
        body: 'Fajr Adhan time.',
        when: fajrAdhan,
        offset: Duration.zero,
        id: _idFor(base, slot++),
      );
      await scheduleWithOffset(
        title: 'Adhan Reminder',
        body: 'Dhuhr Adhan time.',
        when: dhuhrAdhan,
        offset: Duration.zero,
        id: _idFor(base, slot++),
      );
      await scheduleWithOffset(
        title: 'Adhan Reminder',
        body: 'Asr Adhan time.',
        when: asrAdhan,
        offset: Duration.zero,
        id: _idFor(base, slot++),
      );
      await scheduleWithOffset(
        title: 'Adhan Reminder',
        body: 'Maghrib Adhan time.',
        when: maghribAdhan,
        offset: Duration.zero,
        id: _idFor(base, slot++),
      );
      await scheduleWithOffset(
        title: 'Adhan Reminder',
        body: 'Isha Adhan time.',
        when: ishaAdhan,
        offset: Duration.zero,
        id: _idFor(base, slot++),
      );
    }

    // Iqamah (5 minutes before) + Friday Khutbah (fixed time)
    const iqamahLead = Duration(minutes: -5);
    const khutbahLead = Duration(minutes: -5);

// Easy-to-tweak fixed Khutbah time (Central)
    const int khutbahHour = 13;   // 1 PM
    const int khutbahMinute = 30; // :30

    if (iqamahEnabled) {
      // Fajr
      await scheduleWithOffset(
        title: 'Iqamah Reminder',
        body: 'Fajr Iqamah in 5 minutes.',
        when: fajrIqamah,
        offset: iqamahLead,
        id: _idFor(base, slot++),
      );

      // Dhuhr → replace with Friday Khutbah (keep Dhuhr Adhan above)
      if (dateLocal.weekday == DateTime.friday) {
        final DateTime khutbahAt = DateTime(
            dateLocal.year, dateLocal.month, dateLocal.day, khutbahHour, khutbahMinute);

        await scheduleWithOffset(
          title: 'Friday Khutbah',
          body: 'Khutbah starts in 5 mins, in sha’ Allah.',
          when: khutbahAt,
          offset: khutbahLead,
          id: _idFor(base, slot++),
          payload: 'khutbah_alert',
        );
      } else {
        await scheduleWithOffset(
          title: 'Iqamah Reminder',
          body: 'Dhuhr Iqamah in 5 minutes.',
          when: dhuhrIqamah,
          offset: iqamahLead,
          id: _idFor(base, slot++),
        );
      }

      // Asr
      await scheduleWithOffset(
        title: 'Iqamah Reminder',
        body: 'Asr Iqamah in 5 minutes.',
        when: asrIqamah,
        offset: iqamahLead,
        id: _idFor(base, slot++),
      );

      // Maghrib
      await scheduleWithOffset(
        title: 'Iqamah Reminder',
        body: 'Maghrib Iqamah in 5 minutes.',
        when: maghribIqamah,
        offset: iqamahLead,
        id: _idFor(base, slot++),
      );

      // Isha
      await scheduleWithOffset(
        title: 'Iqamah Reminder',
        body: 'Isha Iqamah in 5 minutes.',
        when: ishaIqamah,
        offset: iqamahLead,
        id: _idFor(base, slot++),
      );
    }
  }

  /// Jumu’ah reminder on Friday 12:30 PM (this week).
  Future<void> scheduleJumuahReminderForWeek({
    required DateTime anyDateThisWeekLocal,
    bool enabled = true,
  }) async {
    assert(_initialized, 'AlertsScheduler.init() must be called first');
    if (!enabled) return;

    // Monday=1 ... Friday=5 ... Sunday=7
    final int delta = 5 - anyDateThisWeekLocal.weekday;
    final DateTime friday = (delta >= 0)
        ? anyDateThisWeekLocal.add(Duration(days: delta))
        : anyDateThisWeekLocal.add(Duration(days: 7 + delta));

    final DateTime reminderAt = DateTime(friday.year, friday.month, friday.day, 12, 30);
    if (reminderAt.isBefore(DateTime.now())) return;

    final int id = _idFor(_yyyymmdd(friday), 99); // reserved slot
    await _fln.cancel(id);
    final tz.TZDateTime tzTime = tz.TZDateTime.from(reminderAt, tz.local);

    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      ticker: 'IALFM Jumu’ah',
    );
    const ios = DarwinNotificationDetails(presentAlert: true, presentSound: true);
    const nDetails = NotificationDetails(android: android, iOS: ios);

    // DEV log
    debugPrint('[AlertsScheduler] scheduling Jumu’ah => at=${tzTime.toLocal()} id=$id');

    await _safeZonedSchedule(
      id: id,
      title: "Jumu’ah Reminder",
      body:
      "Jumu'ah Mubarak! Don't forget to perform Ghusl and head to the Masjid early for Khutbah, in shā’ Allāh!",
      when: tzTime,
      details: nDetails,
      payload: 'jumuah_reminder',
    );
  }

  // Android-safe wrapper: try EXACT first, if denied fallback to INEXACT (Android 14).
  Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    String? payload,
  }) async {
    try {
      await _fln.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
        payload: payload,
      );
    } on PlatformException catch (e, st) {
      if (kDebugMode) {
        debugPrint(
            'AlertsScheduler: exact alarm denied (${e.code}). Retrying INEXACT.\n$st');
      }
      await _fln.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
        payload: payload,
      );
    }
  }

  // Debug helper: schedule a test in [seconds].
  Future<void> debugScheduleInSeconds(int seconds) async {
    assert(_initialized, 'AlertsScheduler.init() must be called first');
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(presentAlert: true, presentSound: true);
    const nDetails = NotificationDetails(android: android, iOS: ios);

    await _safeZonedSchedule(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: 'Test Notification',
      body: 'This is a test scheduled ${seconds}s ago.',
      when: when,
      details: nDetails,
      payload: 'debug_test',
    );
  }

  // -- ID helpers
  int _yyyymmdd(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
  int _idFor(int baseYMD, int slot) => baseYMD * 100 + slot;
}