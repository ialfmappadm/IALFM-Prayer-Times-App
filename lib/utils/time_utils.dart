
// time_utils.dart (optimized)

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
  const _ParsedTime(this.hour24, this.minute);
}

/// Faster parser with no heavy regex on hot path:
/// - "h:mm a" (AM/PM, case-insensitive)
/// - "HH:mm"
_ParsedTime _parsePrayerTime(String s) {
  final t = s.trim();

  // Quick path: HH:mm   (e.g., "06:30")
  final colon = t.indexOf(':');
  if (colon > 0 && colon + 3 == t.length) {
    // "H:MM" or "HH:MM" (5 chars or 4 chars total)
    final h = int.parse(t.substring(0, colon));
    final m = int.parse(t.substring(colon + 1));
    return _ParsedTime(h, m);
  }

  // AM/PM path: h:mm a (spaces tolerant)
  final parts = t.split(RegExp(r'\s+'));
  if (parts.length == 2) {
    final hm = parts[0];
    final ap = parts[1].toUpperCase(); // AM or PM
    final c = hm.indexOf(':');
    if (c > 0) {
      var h = int.parse(hm.substring(0, c));
      final m = int.parse(hm.substring(c + 1));
      if (h == 12) h = 0; // 12:xx AM -> 00:xx ; 12:xx PM -> 12:xx after +12
      final hour24 = ap == 'PM' ? h + 12 : h;
      return _ParsedTime(hour24, m);
    }
  }

  throw FormatException('Unsupported time format: $s');
}

/// --- NEW: in-memory cache for a single day ---
/// Key: 'yyyy-mm-dd|name' (name = fajr/dhuhr/asr/maghrib/isha)
class _DayTimeCache {
  final tz.Location loc;
  final DateTime day; // local day at 00:00
  final Map<String, tz.TZDateTime> _cache = {};

  _DayTimeCache(this.loc, this.day);

  tz.TZDateTime get(String name, String hmStr) {
    final key = name;
    final cached = _cache[key];
    if (cached != null) return cached;

    final p = _parsePrayerTime(hmStr);
    final dt = tz.TZDateTime(loc, day.year, day.month, day.day, p.hour24, p.minute);
    _cache[key] = dt;
    return dt;
  }
}

tz.TZDateTime toTzDateTime(tz.Location loc, DateTime day, String hmStr) {
  final p = _parsePrayerTime(hmStr);
  return tz.TZDateTime(loc, day.year, day.month, day.day, p.hour24, p.minute);
}

String format12h(String hmStr) {
  final p = _parsePrayerTime(hmStr);
  final dt = DateTime(2000, 1, 1, p.hour24, p.minute); // dummy date
  return DateFormat('h:mm a').format(dt);
}

class NextPrayer {
  final String name; // fajr/dhuhr/asr/maghrib/isha
  final tz.TZDateTime time; // Adhan begin time
  const NextPrayer(this.name, this.time);
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

  // Use the cache for today's times
  final todayCache = _DayTimeCache(loc, baseDate);
  const order = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  for (final name in order) {
    final beginStr = today.prayers[name]!.begin;
    final begin = todayCache.get(name, beginStr);
    if (begin.isAfter(tzNow)) {
      return NextPrayer(name, begin);
    }
  }

  // If past Isha -> tomorrow's Fajr (fallback to today's if null)
  final tomorrowDate = baseDate.add(const Duration(days: 1));
  final fajrStr = (tomorrow ?? today).prayers['fajr']!.begin;
  final fajr = tz.TZDateTime(
    loc,
    tomorrowDate.year,
    tomorrowDate.month,
    tomorrowDate.day,
    _parsePrayerTime(fajrStr).hour24,
    _parsePrayerTime(fajrStr).minute,
  );
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
  final cache = _DayTimeCache(loc, baseDate);

  final fajrToday = cache.get('fajr', today.prayers['fajr']!.begin);
  final maghribToday = cache.get('maghrib', today.prayers['maghrib']!.begin);

  if (tzNow.isBefore(fajrToday)) return true;
  if (tzNow.isAfter(maghribToday)) return true;
  return false;
}

/// --- OPTIONAL: a tiny tracker you can keep in your widget state ---
/// Use a 1s Timer to only update the remaining time. Recompute next prayer
/// only when now >= nextPrayer.time or when the date changes.
class NextPrayerTracker {
  final tz.Location loc;
  final PrayerDay today;
  final PrayerDay? tomorrow;

  late DateTime _baseLocalDay;
  late NextPrayer _current;

  NextPrayerTracker({
    required this.loc,
    required DateTime nowLocal,
    required this.today,
    required this.tomorrow,
  }) {
    _baseLocalDay = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    _current = getNextPrayer(loc, nowLocal, today, tomorrow);
  }

  NextPrayer get current => _current;

  /// Call this every second with DateTime.now() to get the countdown.
  /// Will only recompute when needed.
  Duration tick(DateTime nowLocal) {
    // Day rollover? (e.g., after midnight)
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    if (todayLocal.isAfter(_baseLocalDay)) {
      _baseLocalDay = todayLocal;
      _current = getNextPrayer(loc, nowLocal, today, tomorrow);
      return _current.time.difference(tz.TZDateTime.from(nowLocal, loc));
    }

    final nowTz = tz.TZDateTime.from(nowLocal, loc);
    if (!nowTz.isBefore(_current.time)) {
      // We crossed the boundary -> compute new next prayer
      _current = getNextPrayer(loc, nowLocal, today, tomorrow);
    }
    return _current.time.difference(nowTz);
  }
}