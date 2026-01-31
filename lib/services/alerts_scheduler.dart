// lib/services/alerts_scheduler.dart
//
// Schedules local notifications for:
// • Prayer Alerts: Adhan (at time) & Iqamah (5 minutes before) for the current day
// • Jumu'ah Reminder: Fridays 12:30 PM local time (1 hour before 1:30 PM)
// Uses flutter_local_notifications + timezone (tz).
//
// Notes:
// • Call AlertsScheduler.instance.init() once at startup (after tz initialized).
// • Re-schedule every midnight (you already have a midnight timer).
// • Call schedulePrayerAlertsForDay(...) and scheduleJumuahReminderForWeek(...)
//   when toggles change or when the day's prayer times refresh.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Convenience: ensure tz.local is correctly set in your app.
/// You already call tz initialization and use America/Chicago.
/// This service assumes DateTime values you pass are in local time.
class AlertsScheduler {
  AlertsScheduler._();
  static final AlertsScheduler instance = AlertsScheduler._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  static const String _channelId   = 'ialfm_alerts';
  static const String _channelName = 'Prayer & Jumu’ah Alerts';
  static const String _channelDesc = 'Adhan/Iqamah alerts and Friday Jumu’ah reminder';
  bool _initialized = false;

  /// Initialize the local notifications plugin.
  /// - [androidSmallIcon] should be a drawable resource name without extension (e.g., 'ic_stat_bell').
  Future<void> init({String androidSmallIcon = 'ic_stat_bell'}) async {
    if (_initialized) return;

    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('ic_stat_bell'); // fallback

    final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      // onDidReceiveLocalNotification -> not needed for iOS < 10 support here
    );

    final initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        if (kDebugMode) {
          debugPrint('[AlertsScheduler] Notification tapped. payload=${r.payload}');
        }
      },
    );

    // Create Android channel with High importance.
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    await _fln
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  /// Request iOS/Android-13+ runtime notification permissions
  /// (local notifications use the same OS permission).
  Future<void> requestPermissions() async {
    await _fln
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _fln
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Cancel ALL scheduled notifications managed by this app.
  Future<void> cancelAll() async {
    await _fln.cancelAll();
  }

  /// Cancel all schedules for a specific day (by ID pattern).
  /// We build IDs as: yyyymmdd * 100 + slot (0..N).
  /// If you call [schedulePrayerAlertsForDay] again for the same date, it's good practice to cancel first.
  Future<void> cancelAllForDate(DateTime dateLocal) async {
    final dayBase = _yyyymmdd(dateLocal);
    for (int slot = 0; slot < 50; slot++) {
      await _fln.cancel(_idFor(dayBase, slot));
    }
  }

  /// Schedule Adhan & Iqamah alerts for the given [dateLocal].
  /// Pass local DateTimes for each prayer time; if null, nothing is scheduled for that slot.
  ///
  /// [adhanEnabled] and [iqamahEnabled] control whether to schedule Adhan / Iqamah alerts.
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

    // Wipe existing for the day, then reschedule.
    await cancelAllForDate(dateLocal);

    final base = _yyyymmdd(dateLocal);
    int slot = 0;

    final android = AndroidNotificationDetails(
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
    final nDetails = NotificationDetails(android: android, iOS: ios);

    /// Schedules a notification at `when + offset`.
    /// Skips if the computed time is in the past.
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
      await _fln.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        nDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
        payload: payload,
      );
    }

    // ——— Adhan alerts (at time)
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

    // ——— Iqamah alerts (5 minutes before)
    const iqamahLead = Duration(minutes: -5);
    if (iqamahEnabled) {
      await scheduleWithOffset(
        title: 'Iqamah Reminder',
        body: 'Fajr Iqamah in ~5 minutes.',
        when: fajrIqamah,
        offset: iqamahLead,
        id: _idFor(base, slot++),
      );
      await scheduleWithOffset(
        title: 'Iqamah Reminder',
        body: 'Dhuhr Iqamah in ~5 minutes.',
        when: dhuhrIqamah,
        offset: iqamahLead,
        id: _idFor(base, slot++),
      );
      await scheduleWithOffset(
        title: 'Iqamah Reminder',
        body: 'Asr Iqamah in ~5 minutes.',
        when: asrIqamah,
        offset: iqamahLead,
        id: _idFor(base, slot++),
      );
      await scheduleWithOffset(
        title: 'Iqamah Reminder',
        body: 'Maghrib Iqamah in ~5 minutes.',
        when: maghribIqamah,
        offset: iqamahLead,
        id: _idFor(base, slot++),
      );
      await scheduleWithOffset(
        title: 'Iqamah Reminder',
        body: 'Isha Iqamah in ~5 minutes.',
        when: ishaIqamah,
        offset: iqamahLead,
        id: _idFor(base, slot++),
      );
    }
  }

  /// Schedule the Jumu’ah reminder for the given week.
  /// This will schedule a single reminder at Friday **12:30 PM** local time.
  /// Call once per week (or re‑call freely; it cancels same‑day/ID before scheduling).
  Future<void> scheduleJumuahReminderForWeek({
    required DateTime anyDateThisWeekLocal,
    bool enabled = true,
  }) async {
    assert(_initialized, 'AlertsScheduler.init() must be called first');
    if (!enabled) return;

    // DateTime.weekday: Monday=1 ... Sunday=7; Friday=5
    final int delta = 5 - anyDateThisWeekLocal.weekday;
    final DateTime friday =
    (delta >= 0) ? anyDateThisWeekLocal.add(Duration(days: delta))
        : anyDateThisWeekLocal.add(Duration(days: 7 + delta));

    // 12:30 PM local
    final DateTime reminderAt = DateTime(friday.year, friday.month, friday.day, 12, 30);
    if (reminderAt.isBefore(DateTime.now())) return;

    final int id = _idFor(_yyyymmdd(friday), 99); // reserved slot for Jumu’ah
    await _fln.cancel(id); // replace same-day reminder if present

    final tz.TZDateTime tzTime = tz.TZDateTime.from(reminderAt, tz.local);
    final android = AndroidNotificationDetails(
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
    final nDetails = NotificationDetails(android: android, iOS: ios);
    const String title = "Jumu’ah Reminder";
    const String body  =
        "Jumu'ah Mubarak! Don't forget to perform Ghusl and head to the Masjid early for Khutbah, in shā’ Allāh!";

    await _fln.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      nDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
      payload: 'jumuah_reminder',
    );
  }

  // ── ID helpers ─────────────────────────────────────────────────────────────
  int _yyyymmdd(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
  int _idFor(int baseYMD, int slot) => baseYMD * 100 + slot;
}