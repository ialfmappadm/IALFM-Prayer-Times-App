
// lib/models.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Represents a single prayer's times.
class PrayerTime {
  final String begin;  // 'HH:mm' 24h
  final String iqamah; // 'HH:mm' 24h

  PrayerTime({required this.begin, required this.iqamah});

  factory PrayerTime.fromJson(Map<String, dynamic> j) =>
      PrayerTime(begin: j['begin'] as String, iqamah: j['iqamah'] as String);
}

/// Represents one calendar day of prayer times.
class PrayerDay {
  final DateTime date;                      // ISO local date (e.g., '2026-01-14')
  final Map<String, PrayerTime> prayers;    // fajr, dhuhr, asr, maghrib, isha
  final String? sunrise;
  final String? sunset;
  final int serial;

  PrayerDay({
    required this.date,
    required this.prayers,
    this.sunrise,
    this.sunset,
    required this.serial,
  });

  factory PrayerDay.fromJson(Map<String, dynamic> j) {
    final date = DateTime.parse(j['date'] as String);

    final Map<String, dynamic> raw = j['prayers'] as Map<String, dynamic>;
    final prayers = raw.map(
          (k, v) => MapEntry(k, PrayerTime.fromJson(v as Map<String, dynamic>)),
    );

    final serial = (j['serial'] is int)
        ? j['serial'] as int
        : int.tryParse(j['serial']?.toString() ?? '0') ?? 0;

    return PrayerDay(
      date: date,
      prayers: prayers,
      sunrise: j['sunrise'] as String?,
      sunset: j['sunset'] as String?,
      serial: serial,
    );
  }
}

/// Loads prayer days from local storage if available; otherwise falls back to asset.
/// Pass `year` so the asset fallback matches the current year.
/// Local path: /data/data/<pkg>/app_flutter/prayer_times_local.json
Future<List<PrayerDay>> loadPrayerDays({int? year}) async {
  // 1) Try local override first.
  try {
    final dir = await getApplicationDocumentsDirectory();
    final localFile = File('${dir.path}/prayer_times_local.json');
    if (await localFile.exists()) {
      final txt = await localFile.readAsString();
      final decoded = jsonDecode(txt);
      final List<dynamic> arr = _coerceToList(decoded);
      final result =
      arr.map((e) => PrayerDay.fromJson(e as Map<String, dynamic>)).toList();
      if (result.isNotEmpty) {
        debugPrint(
            'loadPrayerDays(): using LOCAL file ${localFile.path} (count=${result.length})');
        return result;
      }
    }
  } catch (e, st) {
    debugPrint('loadPrayerDays(): local read failed: $e\n$st');
  }

  // 2) Fallback to asset for the given year.
  final y = year ?? DateTime.now().year;
  final assetPath = 'assets/data/prayer_times_$y.json';
  final txt = await rootBundle.loadString(assetPath);
  final decoded = jsonDecode(txt);
  final List<dynamic> arr = _coerceToList(decoded);
  debugPrint('loadPrayerDays(): using ASSET $assetPath (count=${arr.length})');
  return arr
      .map((e) => PrayerDay.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Accepts either:
///  - a List of day objects,
///  - a Map keyed by date: { "2026-01-01": {...}, ... },
///  - or { "days": [ ... ] } wrapper.
List<dynamic> _coerceToList(dynamic decoded) {
  if (decoded is List) return decoded;
  if (decoded is Map<String, dynamic>) {
    if (decoded['days'] is List) return decoded['days'] as List<dynamic>;
    return decoded.values.toList();
  }
  throw FormatException('Unsupported JSON structure for prayer times');
}
