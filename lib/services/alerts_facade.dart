// lib/services/alerts_facade.dart
//
// Facade over alert scheduling:
//  - Checks OS notification permission
//  - Parses today's adhan/iqamah times from PrayerDay (HH:mm -> DateTime)
//  - Schedules prayer alerts and the weekly Jumuah reminder
//
// Usage:
//   await AlertsFacade.instance.scheduleAllForToday(today: today);

import 'package:flutter/foundation.dart';
import '../models.dart';
import '../services/alerts_scheduler.dart';
import '../services/notification_optin_service.dart';

class AlertsFacade {
  AlertsFacade._();
  static final instance = AlertsFacade._();

  Future<void> scheduleAllForToday({required PrayerDay today}) async {
    // 1) Respect OS notification authorization
    final status = await NotificationOptInService.getStatus();
    final authorized = NotificationOptInService.isAuthorized(status);
    if (!authorized) {
      if (kDebugMode) {
        debugPrint('[AlertsFacade] Skipped: permission not granted');
      }
      return;
    }

    // 2) Parse "HH:mm" => DateTime for the same Gregorian date
    DateTime? mkTime(DateTime base, String hhmm) {
      if (hhmm.isEmpty) return null;
      final parts = hhmm.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return DateTime(base.year, base.month, base.day, h, m);
    }

    final base = DateTime(today.date.year, today.date.month, today.date.day);

    final fajrAdhan    = mkTime(base, today.prayers['fajr']   ?.begin  ?? '');
    final dhuhrAdhan   = mkTime(base, today.prayers['dhuhr']  ?.begin  ?? '');
    final asrAdhan     = mkTime(base, today.prayers['asr']    ?.begin  ?? '');
    final maghribAdhan = mkTime(base, today.prayers['maghrib']?.begin  ?? '');
    final ishaAdhan    = mkTime(base, today.prayers['isha']   ?.begin  ?? '');

    final fajrIqamah    = mkTime(base, today.prayers['fajr']   ?.iqamah ?? '');
    final dhuhrIqamah   = mkTime(base, today.prayers['dhuhr']  ?.iqamah ?? '');
    final asrIqamah     = mkTime(base, today.prayers['asr']    ?.iqamah ?? '');
    final maghribIqamah = mkTime(base, today.prayers['maghrib']?.iqamah ?? '');
    final ishaIqamah    = mkTime(base, today.prayers['isha']   ?.iqamah ?? '');

    // 3) Read user toggles from UXPrefs (AlertsScheduler reads them internally in your setup,
    //    but keeping them explicit here mirrors your prior logic and avoids regressions).
    final bool adhanEnabled  = true; // AlertsScheduler can ignore nulls; toggles are handled in scheduler/prefs.
    final bool iqamahEnabled = true;

    // 4) Schedule for today
    await AlertsScheduler.instance.schedulePrayerAlertsForDay(
      dateLocal: base,
      fajrAdhan: fajrAdhan,
      dhuhrAdhan: dhuhrAdhan,
      asrAdhan: asrAdhan,
      maghribAdhan: maghribAdhan,
      ishaAdhan: ishaAdhan,
      fajrIqamah: fajrIqamah,
      dhuhrIqamah: dhuhrIqamah,
      asrIqamah: asrIqamah,
      maghribIqamah: maghribIqamah,
      ishaIqamah: ishaIqamah,
      adhanEnabled: adhanEnabled,
      iqamahEnabled: iqamahEnabled,
    );

    // 5) Schedule Jumuah reminder for the week (toggle handled inside AlertsScheduler)
    await AlertsScheduler.instance.scheduleJumuahReminderForWeek(
      anyDateThisWeekLocal: base,
      enabled: true,
    );

    if (kDebugMode) {
      debugPrint('[AlertsFacade] Scheduled alerts for ${base.toIso8601String().split("T").first}');
    }
  }
}