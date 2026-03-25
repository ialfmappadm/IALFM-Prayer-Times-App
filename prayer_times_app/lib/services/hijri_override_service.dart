import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // for kReleaseMode & debugPrint
import '../ux_prefs.dart';

class HijriYMD {
  final int y, m, d;
  const HijriYMD(this.y, this.m, this.d);
  @override
  String toString() =>
      '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

typedef HijriResolver = Future<HijriYMD> Function(DateTime g);

/// Structured result for diagnostics / UI.
class HijriOverrideResult {
  final bool success;
  final String message;
  final int? appliedDelta; // e.g., 0, +1, -1; null if none applied
  final HijriYMD? targetHijri;
  final String bucketUsed;
  const HijriOverrideResult({
    required this.success,
    required this.message,
    required this.bucketUsed,
    this.appliedDelta,
    this.targetHijri,
  });
  @override
  String toString() =>
      'HijriOverrideResult(success=$success, delta=$appliedDelta, target=$targetHijri, bucket=$bucketUsed, "$message")';
}

/// Reads: gs://bucket/hijri_date/hijri_override.json
/// File formats accepted (either key is fine):
///   { "hijri": "DD/MM/YYYY" }            // e.g., "08/08/1447"
///   { "hijri_iso": "YYYY-MM-DD" }        // e.g., "1447-08-08"
///
/// Behavior:
/// - Only acts if a file is present.
/// - Compares target hijri (from JSON) to app's hijri for today+delta, with delta in [-2..+2].
/// - If matched, sets UXPrefs.hijriBaseAdjust=delta and UXPrefs.hijriOffset=0.
/// - Returns a structured result describing what happened.
class HijriOverrideService {
  static const String _relativePath = 'hijri_date/hijri_override.json';
  static const int _maxSize = 16 * 1024;

  /// Call at startup AND/OR on demand (e.g., from More page) to re-check.
  ///
  /// [resolveAppHijri]: function that converts a Gregorian date to your app's Hijri Y/M/D.
  /// [bucketOverride]:  pass the GS URL of your storage bucket if the default bucket isn't set.
  /// [now]:             inject a fixed "today" for tests (optional).
  /// [log]:             print diagnostic messages to console.
  static Future<HijriOverrideResult> applyIfPresent({
    required HijriResolver resolveAppHijri,
    String? bucketOverride,
    DateTime? now,
    bool log = false,
  }) async {
    final storage = (bucketOverride != null && bucketOverride.isNotEmpty)
        ? FirebaseStorage.instanceFor(bucket: bucketOverride)
        : FirebaseStorage.instance;

    final bucketName = (bucketOverride ?? 'DEFAULT_BUCKET');

    try {
      final ref = storage.ref(_relativePath);
      if (log) _d('Storage bucket: $bucketName, path: $_relativePath');

      final raw = await ref.getData(_maxSize);
      if (raw == null || raw.isEmpty) {
        final msg = 'No override file found';
        if (log) _d(msg);
        return HijriOverrideResult(
          success: false,
          message: msg,
          bucketUsed: bucketName,
        );
      }

      final map = jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
      final HijriYMD? target =
          _parseHijriDDMMYYYY(map['hijri']) ?? _parseHijriISO(map['hijri_iso']);

      if (target == null) {
        final msg = 'Invalid JSON format. Expect "hijri":"DD/MM/YYYY" or "hijri_iso":"YYYY-MM-DD".';
        if (log) _d(msg);
        return HijriOverrideResult(
          success: false,
          message: msg,
          bucketUsed: bucketName,
        );
      }

      final DateTime today = now ?? DateTime.now();
      if (log) _d('Target hijri: $target, trying deltas [-2..+2]');

      for (int delta = -2; delta <= 2; delta++) {
        final g = today.add(Duration(days: delta));
        final appHijri = await resolveAppHijri(g);
        if (log) _d('  delta=$delta -> appHijri=$appHijri');

        if (appHijri.y == target.y &&
            appHijri.m == target.m &&
            appHijri.d == target.d) {
          // Found a match; apply internal base adjustment and neutralize user offset.
          await UXPrefs.setHijriBaseAdjust(delta);
          await UXPrefs.setHijriOffset(0);
          final msg = 'Applied base delta=$delta and set user offset=0';
          if (log) _d(msg);

          return HijriOverrideResult(
            success: true,
            message: msg,
            appliedDelta: delta,
            targetHijri: target,
            bucketUsed: bucketName,
          );
        }
      }

      final msg = 'No matching hijri in [-2..+2] for target=$target. No changes applied.';
      if (log) _d(msg);
      return HijriOverrideResult(
        success: false,
        message: msg,
        targetHijri: target,
        bucketUsed: bucketName,
      );
    } catch (e) {
      final msg = 'Error reading override: $e';
      if (log) _d(msg);
      return HijriOverrideResult(
        success: false,
        message: msg,
        bucketUsed: bucketName,
      );
    }
  }

  // "08/08/1447" -> y=1447, m=8, d=8
  static HijriYMD? _parseHijriDDMMYYYY(dynamic s) {
    if (s is! String) return null;
    final parts = s.trim().split('/');
    if (parts.length != 3) return null;
    final dd = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    final yy = int.tryParse(parts[2]);
    if (dd == null || mm == null || yy == null) return null;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 30) return null;
    return HijriYMD(yy, mm, dd);
  }

  // "1447-08-08" -> y=1447, m=8, d=8
  static HijriYMD? _parseHijriISO(dynamic s) {
    if (s is! String) return null;
    final parts = s.trim().split('-');
    if (parts.length != 3) return null;
    final yy = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    final dd = int.tryParse(parts[2]);
    if (yy == null || mm == null || dd == null) return null;
    if (mm < 1 || mm > 12 || dd < 1 || dd > 30) return null;
    return HijriYMD(yy, mm, dd);
  }

  static void _d(String s) {
    if (!kReleaseMode) debugPrint('[HijriOverride] $s');
  }

}