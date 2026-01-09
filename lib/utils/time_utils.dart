
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tzdb;
import 'package:timezone/timezone.dart' as tz;
import '../models.dart';

// Initialize to America/Chicago
Future<tz.Location> initCentralTime() async {
  tzdb.initializeTimeZones();
  return tz.getLocation('America/Chicago');
}

/// Parsed time holder (24-hour)
class _ParsedTime {
  final int hour24;
  final int minute;
  _ParsedTime(this.hour24, this.minute);
}

/// Robust parser: supports "h:mm a" (e.g., "3:15 PM") and "HH:mm" (e.g., "06:30")
_ParsedTime _parsePrayerTime(String s) {
  final t = s.trim();

  // Try "h:mm a" (AM/PM, case-insensitive)
  final apMatch = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
      .firstMatch(t);
  if (apMatch != null) {
    var h = int.parse(apMatch.group(1)!);
    final m = int.parse(apMatch.group(2)!);
    final ap = apMatch.group(3)!.toUpperCase(); // "AM" or "PM"

    // Convert to 24h: 12:xx AM => 00:xx, 12:xx PM => 12:xx
    if (h == 12) h = 0;
    final hour24 = ap == 'PM' ? h + 12 : h;
    return _ParsedTime(hour24, m);
  }

  // Try "HH:mm"
  final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(t);
  if (match24 != null) {
    final h = int.parse(match24.group(1)!);
    final m = int.parse(match24.group(2)!);
    return _ParsedTime(h, m);
  }

  throw FormatException('Unsupported time format: $s');
}

/// Build a TZDateTime from a day and HM string ("h:mm a" or "HH:mm")
tz.TZDateTime toTzDateTime(tz.Location loc, DateTime day, String hmStr) {
  final p = _parsePrayerTime(hmStr);
  return tz.TZDateTime(loc, day.year, day.month, day.day, p.hour24, p.minute);
}

/// Format any supported input into "h:mm a" (e.g., "3:15 PM")
String format12h(String hmStr) {
  final p = _parsePrayerTime(hmStr);
  final dt = DateTime(2000, 1, 1, p.hour24, p.minute); // dummy date
  return DateFormat('h:mm a').format(dt);
}

class NextPrayer {
  final String name; // fajr/dhuhr/asr/maghrib/isha
  final tz.TZDateTime time; // Adhan begin time
  NextPrayer(this.name, this.time);
}

/// Compute next prayer relative to "nowLocal" in America/Chicago
NextPrayer getNextPrayer(
    tz.Location loc,
    DateTime nowLocal,
    PrayerDay today,
    PrayerDay? tomorrow,
    ) {
  final tzNow = tz.TZDateTime.from(nowLocal, loc);
  final baseDate = DateTime(tzNow.year, tzNow.month, tzNow.day);

  const order = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  for (final name in order) {
    final begin = toTzDateTime(loc, baseDate, today.prayers[name]!.begin);
    if (begin.isAfter(tzNow)) {
      return NextPrayer(name, begin);
    }
  }

  // If past Isha, show tomorrow's Fajr (fall back to today's if null)
  final tomorrowDate = baseDate.add(const Duration(days: 1));
  final fajrStr = (tomorrow ?? today).prayers['fajr']!.begin;
  final fajr = toTzDateTime(loc, tomorrowDate, fajrStr);
  return NextPrayer('fajr', fajr);
}

String formatCountdown(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
}

/// Night: before Fajr or after Maghrib on the same Central day
bool isNight(
    tz.Location loc,
    DateTime nowLocal,
    PrayerDay today,
    PrayerDay? tomorrow,
    ) {
  final tzNow = tz.TZDateTime.from(nowLocal, loc);
  final baseDate = DateTime(tzNow.year, tzNow.month, tzNow.day);
  final fajrToday = toTzDateTime(loc, baseDate, today.prayers['fajr']!.begin);
  final maghribToday = toTzDateTime(loc, baseDate, today.prayers['maghrib']!.begin);

  if (tzNow.isBefore(fajrToday)) return true;
  if (tzNow.isAfter(maghribToday)) return true;
  return false;
}
