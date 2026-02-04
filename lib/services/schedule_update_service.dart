// lib/services/schedule_update_service.dart
//
// Encapsulates:
//  - Refresh-on-startup (best-effort cloud pull + discreet SnackBar gating)
//  - Once-per-day metadata peek (only download if remote is newer & recent)
//  - All related UXPrefs keys consolidated here
//
// The service is UI-agnostic: it returns a result telling the caller whether
// to show the SnackBar and the ISO timestamp to persist after showing.

import 'dart:async';
// Repository (Storage -> local persist)
import 'package:firebase_storage/firebase_storage.dart';

import '../prayer_times_firebase.dart';
import '../ux_prefs.dart';

class ScheduleUpdateResult {
  final bool updated;        // local JSON changed this call
  final bool showSnack;      // caller should show “Prayer times updated”
  final String? whenIsoUtc;  // meta['lastUpdated'] as ISO string (UTC) if available
  const ScheduleUpdateResult({
    required this.updated,
    required this.showSnack,
    required this.whenIsoUtc,
  });
}

class ScheduleUpdateService {
  ScheduleUpdateService._();
  static final instance = ScheduleUpdateService._();

  // UXPrefs keys (centralized)
  static const kLastDailyCheckYMD   = 'ux.schedule.lastDailyCheckYMD';
  static const kLastCloudStamp      = 'ux.schedule.lastCloudStamp';
  static const kLastShownUpdatedAt  = 'ux.schedule.lastShownUpdatedAt';

  // Tuning: "fresh" window to show discrete SnackBar
  static const Duration _freshSnackWindow = Duration(minutes: 2);
  // "few hours" window for a cloud stamp to be considered recent
  static const Duration _freshCloudStampMaxAge = Duration(hours: 6);

  final PrayerTimesRepository _repo = PrayerTimesRepository();

  /// Run once at app startup. Best-effort refresh; returns gating info for SnackBar.
  Future<ScheduleUpdateResult> refreshOnStartup() async {
    bool updated = false;
    String? whenIsoUtc;

    try {
      updated = await _repo.refreshFromFirebase(year: DateTime.now().year);
      if (updated) {
        final meta = await _repo.readMeta();
        whenIsoUtc = (meta?['lastUpdated'] as String?)?.trim();

        // Decide whether the caller should show a SnackBar
        final whenLocal = _tryParseLocal(whenIsoUtc);
        final isFresh = whenLocal != null &&
            DateTime.now().difference(whenLocal) <= _freshSnackWindow;
        final lastShown = await UXPrefs.getString(kLastShownUpdatedAt);
        final shouldShow = isFresh && (whenIsoUtc?.isNotEmpty ?? false) && whenIsoUtc != lastShown;

        // Record baseline cloud stamp for future daily peeks
        if (whenIsoUtc != null && whenIsoUtc.isNotEmpty) {
          await UXPrefs.setString(kLastCloudStamp, whenIsoUtc);
        }

        return ScheduleUpdateResult(
          updated: true,
          showSnack: shouldShow,
          whenIsoUtc: whenIsoUtc,
        );
      }
    } catch (_) {
      // Any cloud error -> keep local; nothing to show
    }

    return const ScheduleUpdateResult(
      updated: false,
      showSnack: false,
      whenIsoUtc: null,
    );
  }

  /// Once per day (first foreground), peek cloud metadata; download only if newer & recent.
  /// Returns whether caller should show SnackBar now.
  Future<ScheduleUpdateResult> maybeDailyCloudCheck() async {
    try {
      // Gate: only once per calendar day
      final today = _ymd(DateTime.now());
      final last = await UXPrefs.getString(kLastDailyCheckYMD);
      if (last == today) {
        return const ScheduleUpdateResult(updated: false, showSnack: false, whenIsoUtc: null);
      }
      await UXPrefs.setString(kLastDailyCheckYMD, today);

      final year = DateTime.now().year;
      final ref = FirebaseStorage.instance.ref('prayer_times/$year.json');

      FullMetadata meta;
      try {
        meta = await ref.getMetadata();
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') {
          // No cloud file -> nothing to do
          return const ScheduleUpdateResult(updated: false, showSnack: false, whenIsoUtc: null);
        }
        // Some other storage error -> skip silently
        return const ScheduleUpdateResult(updated: false, showSnack: false, whenIsoUtc: null);
      }

      final stamp = meta.updated ?? meta.timeCreated; // DateTime?
      if (stamp == null) {
        return const ScheduleUpdateResult(updated: false, showSnack: false, whenIsoUtc: null);
      }

      // Compare with last known cloud stamp
      final lastKnownIso = await UXPrefs.getString(kLastCloudStamp);
      final lastKnown = (lastKnownIso != null && lastKnownIso.isNotEmpty)
          ? DateTime.tryParse(lastKnownIso)
          : null;

      final isRecent = DateTime.now().difference(stamp.toLocal()) <= _freshCloudStampMaxAge;
      final isNewer = (lastKnown == null) || stamp.isAfter(lastKnown);
      if (!(isRecent && isNewer)) {
        return const ScheduleUpdateResult(updated: false, showSnack: false, whenIsoUtc: null);
      }

      // Pull content now
      final updated = await _repo.refreshFromFirebase(year: year);
      if (updated) {
        final metaLocal = await _repo.readMeta();
        final whenIsoUtc = (metaLocal?['lastUpdated'] as String?)?.trim();
        final whenLocal = _tryParseLocal(whenIsoUtc);

        final isFresh = whenLocal != null &&
            DateTime.now().difference(whenLocal) <= _freshSnackWindow;
        final lastShown = await UXPrefs.getString(kLastShownUpdatedAt);
        final shouldShow = isFresh && (whenIsoUtc?.isNotEmpty ?? false) && whenIsoUtc != lastShown;

        // Persist new cloud baseline
        await UXPrefs.setString(kLastCloudStamp, stamp.toUtc().toIso8601String());

        return ScheduleUpdateResult(
          updated: true,
          showSnack: shouldShow,
          whenIsoUtc: whenIsoUtc,
        );
      } else {
        // metadata looked newer but content pull failed -> try next day
        return const ScheduleUpdateResult(updated: false, showSnack: false, whenIsoUtc: null);
      }
    } catch (_) {
      return const ScheduleUpdateResult(updated: false, showSnack: false, whenIsoUtc: null);
    }
  }

  // ---- helpers ----
  DateTime? _tryParseLocal(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    return DateTime.tryParse(iso)?.toLocal();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}