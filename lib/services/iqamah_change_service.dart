// lib/services/iqamah_change_service.dart
import '../models.dart';

/// Minimal snapshot of iqamah times for equality/diff checks.
class _IqamahSnapshot {
  final String fajr;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  const _IqamahSnapshot({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _IqamahSnapshot &&
        fajr == other.fajr &&
        dhuhr == other.dhuhr &&
        asr == other.asr &&
        maghrib == other.maghrib &&
        isha == other.isha;
  }

  @override
  int get hashCode => Object.hash(fajr, dhuhr, asr, maghrib, isha);
}

class IqamahChange {
  /// The date the **new** iqamah times start (the first day of the new window).
  final DateTime changeDate;
  /// Relative to "today": 2 → heads‑up; 1 → night‑before.
  final int daysToChange;

  final bool fajrChanged;
  final bool dhuhrChanged;
  final bool asrChanged;
  final bool maghribChanged;
  final bool ishaChanged;

  /// Pretty “A → B” lines; keys: Fajr, Dhuhr, Asr, Maghrib, Isha
  final Map<String, String> prettyDiffs;

  const IqamahChange({
    required this.changeDate,
    required this.daysToChange,
    required this.fajrChanged,
    required this.dhuhrChanged,
    required this.asrChanged,
    required this.maghribChanged,
    required this.ishaChanged,
    required this.prettyDiffs,
  });

  bool get anyChange =>
      fajrChanged || dhuhrChanged || asrChanged || maghribChanged || ishaChanged;
  bool get fajrEmphasis => fajrChanged;
  String get changeYMD => _ymd(changeDate);
}

/// Computes the **next** change purely from local daily times:
/// - If TODAY→TOMORROW differs → change is TOMORROW (daysToChange=1)
/// - Else if TOMORROW→DAY_AFTER differs → change is DAY_AFTER (daysToChange=2)
/// - Else → null (no change soon)
class IqamahChangeService {
  static IqamahChange? detectUpcomingChange({
    required List<PrayerDay> allDays,
    required DateTime todayLocal,
  }) {
    if (allDays.isEmpty) return null;

    DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
    final t0 = day(todayLocal);
    final t1 = t0.add(const Duration(days: 1));
    final t2 = t0.add(const Duration(days: 2));

    final d0 = _find(allDays, t0);
    final d1 = _find(allDays, t1);
    final d2 = _find(allDays, t2);
    if (d1 == null) return null;

    final s0 = d0 == null ? null : _snap(d0);
    final s1 = _snap(d1);
    final s2 = d2 == null ? null : _snap(d2);

    // Case A: change tomorrow (today→tomorrow differs)
    if (s0 != null && s0 != s1) {
      final diffs = _prettyDiffs(from: d0!, to: d1);
      return IqamahChange(
        changeDate: t1,
        daysToChange: 1,
        fajrChanged: diffs.containsKey('Fajr'),
        dhuhrChanged: diffs.containsKey('Dhuhr'),
        asrChanged: diffs.containsKey('Asr'),
        maghribChanged: diffs.containsKey('Maghrib'),
        ishaChanged: diffs.containsKey('Isha'),
        prettyDiffs: diffs,
      );
    }

    // Case B: two-day heads-up (tomorrow→day-after differs)
    if (s2 != null && s1 != s2) {
      final diffs = _prettyDiffs(from: d1, to: d2!);
      return IqamahChange(
        changeDate: t2,
        daysToChange: 2,
        fajrChanged: diffs.containsKey('Fajr'),
        dhuhrChanged: diffs.containsKey('Dhuhr'),
        asrChanged: diffs.containsKey('Asr'),
        maghribChanged: diffs.containsKey('Maghrib'),
        ishaChanged: diffs.containsKey('Isha'),
        prettyDiffs: diffs,
      );
    }

    return null;
  }

  /// Helper used by T‑1 prompts (night‑before) to gate by Maghrib.
  static bool isAfterMaghrib({
    required PrayerDay today,
    required DateTime nowLocal,
  }) {
    DateTime? parseHHmm(DateTime base, String hhmm) {
      if (hhmm.isEmpty) return null;
      final p = hhmm.split(':');
      if (p.length != 2) return null;
      final h = int.tryParse(p[0]); final m = int.tryParse(p[1]);
      if (h == null || m == null) return null;
      return DateTime(base.year, base.month, base.day, h, m);
    }

    final base = DateTime(today.date.year, today.date.month, today.date.day);
    // Use **Adhan** for “after Maghrib”
    final maghribAdhan = parseHHmm(base, today.prayers['maghrib']?.begin ?? '');
    final threshold = maghribAdhan ?? DateTime(base.year, base.month, base.day, 19, 0);
    return nowLocal.isAfter(threshold) || nowLocal.isAtSameMomentAs(threshold);
  }

  // --- internals ---
  static PrayerDay? _find(List<PrayerDay> days, DateTime d) {
    for (final x in days) {
      if (x.date.year == d.year && x.date.month == d.month && x.date.day == d.day) {
        return x;
      }
    }
    return null;
  }

  static _IqamahSnapshot _snap(PrayerDay d) {
    String q(String name) => d.prayers[name]?.iqamah ?? '';
    return _IqamahSnapshot(
      fajr: q('fajr'),
      dhuhr: q('dhuhr'),
      asr: q('asr'),
      maghrib: q('maghrib'),
      isha: q('isha'),
    );
  }

  static Map<String, String> _prettyDiffs({
    required PrayerDay from,
    required PrayerDay to,
  }) {
    String fmt(String s) => s; // already 'HH:mm' — localize later if needed
    Map<String, String> out = {};
    void addIf(String label, String a, String b) {
      if (a != b) out[label] = '${fmt(a)} → ${fmt(b)}';
    }
    addIf('Fajr', from.prayers['fajr']?.iqamah ?? '', to.prayers['fajr']?.iqamah ?? '');
    addIf('Dhuhr', from.prayers['dhuhr']?.iqamah ?? '', to.prayers['dhuhr']?.iqamah ?? '');
    addIf('Asr', from.prayers['asr']?.iqamah ?? '', to.prayers['asr']?.iqamah ?? '');
    addIf('Maghrib', from.prayers['maghrib']?.iqamah ?? '', to.prayers['maghrib']?.iqamah ?? '');
    addIf('Isha', from.prayers['isha']?.iqamah ?? '', to.prayers['isha']?.iqamah ?? '');
    return out;
  }
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';