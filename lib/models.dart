
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class PrayerTime {
  final String begin;   // 'HH:mm' 24h
  final String iqamah;  // 'HH:mm' 24h
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

  PrayerDay({required this.date, required this.prayers, this.sunrise, this.sunset, required this.serial});

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

Future<List<PrayerDay>> loadPrayerDays() async {
  final txt = await rootBundle.loadString('assets/data/prayer_times_2026.json');
  final List<dynamic> arr = jsonDecode(txt);
  return arr.map((e) => PrayerDay.fromJson(e as Map<String, dynamic>)).toList();
}
