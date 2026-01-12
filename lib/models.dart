
// lib/models.dart
import 'dart:convert';
import 'prayer_times_firebase.dart';

class PrayerTime {
  final String begin;  // 'HH:mm'
  final String iqamah; // 'HH:mm'
  PrayerTime({required this.begin, required this.iqamah});
  factory PrayerTime.fromJson(Map<String, dynamic> j)
  => PrayerTime(begin: j['begin'], iqamah: j['iqamah']);
}

class PrayerDay {
  final DateTime date;                   // ISO local date
  final Map<String, PrayerTime> prayers; // fajr, dhuhr, asr, maghrib, isha
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
    return PrayerDay(
      date: date,
      prayers: prayers,
      sunrise: j['sunrise'] as String?,
      sunset: j['sunset'] as String?,
      serial: j['serial'] as int,
    );
  }
}

/// Canonical loader: reads local file; on first run falls back to bundled asset
/// and persists it. No network dependency.
Future<List<PrayerDay>> loadPrayerDays() async {
  final repo = PrayerTimesRepository();
  final txt = await repo.loadLocalJsonOrAsset();
  final List<dynamic> arr = jsonDecode(txt);
  return arr
      .map((e) => PrayerDay.fromJson(e as Map<String, dynamic>))
      .toList();
}