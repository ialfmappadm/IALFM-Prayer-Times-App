// lib/services/iqamah_change_service.dart
//
// Iqamah change detector (service-only; no UI).
// - Compares ONLY Fajr, Dhuhr, Asr, Isha between consecutive days
// - Ignores Maghrib entirely (no parsing, no comparisons)
// - Detects the next change as either T+1 (Δ=1) or T+2 (Δ=2)
// - Uses a fixed evening cutoff (default 19:00 local) for “night-before” gating
// - Emits UI-friendly fields (12-hour format, friendly long date, ordered lines)
// - Absolutely no UI logic (no icons, bullets, or widgets)

import 'package:flutter/foundation.dart' show debugPrint;
import '../models.dart';

// ---------- Utilities: 12-hour time + friendly date ----------

String _to12h(String hhmm) {
  // Input: "HH:mm"
  if (hhmm.isEmpty) return '';
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return hhmm;

  final isPM = h >= 12;
  int h12 = h % 12;
  if (h12 == 0) h12 = 12;

  final mm = m.toString().padLeft(2, '0');
  final suffix = isPM ? 'PM' : 'AM';
  return '$h12:$mm $suffix';
}

const _monthNames = <int, String>{
  1: 'January',
  2: 'February',
  3: 'March',
  4: 'April',
  5: 'May',
  6: 'June',
  7: 'July',
  8: 'August',
  9: 'September',
  10: 'October',
  11: 'November',
  12: 'December',
};

const _weekdayNames = <int, String>{
  DateTime.monday: 'Monday',
  DateTime.tuesday: 'Tuesday',
  DateTime.wednesday: 'Wednesday',
  DateTime.thursday: 'Thursday',
  DateTime.friday: 'Friday',
  DateTime.saturday: 'Saturday',
  DateTime.sunday: 'Sunday',
};

String _friendlyLongDate(DateTime d) {
  final wd = _weekdayNames[d.weekday] ?? '';
  final mo = _monthNames[d.month] ?? '';
  return '$wd, $mo ${d.day}, ${d.year}';
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

/// Lightweight snapshot for comparison (Fajr, Dhuhr, Asr, Isha only).
class _IqamahSnapshot {
  final String fajr;
  final String dhuhr;
  final String asr;
  final String isha;

  const _IqamahSnapshot({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.isha,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _IqamahSnapshot &&
        fajr == other.fajr &&
        dhuhr == other.dhuhr &&
        asr == other.asr &&
        isha == other.isha;
  }

  @override
  int get hashCode => Object.hash(fajr, dhuhr, asr, isha);

  Map<String, String> toMap() => {
    'Fajr': fajr,
    'Dhuhr': dhuhr,
    'Asr': asr,
    'Isha': isha,
  };

  @override
  String toString() => toMap().toString();
}

class IqamahChange {
  /// The date the **new** iqamah times start.
  final DateTime changeDate;

  /// Relative to “today”: 2 → heads‑up; 1 → night‑before.
  final int daysToChange;

  final bool fajrChanged;
  final bool dhuhrChanged;
  final bool asrChanged;
  final bool ishaChanged;

  /// Pretty “A → B” lines in 24h; keys from: Fajr, Dhuhr, Asr, Isha.
  final Map<String, String> prettyDiffs;

  /// Pretty “A → B” in **12h**; keys from: Fajr, Dhuhr, Asr, Isha.
  final Map<String, String> prettyDiffs12;

  /// Ordered lines for easy UI rendering (Salah order: Fajr, Dhuhr, Asr, Isha).
  /// Each entry: (label, old12, new12)
  final List<({String label, String old12, String new12})> uiLines12;

  /// `true` if exactly one Salah changes.
  final bool isSingleChange;

  /// If single change → these are set; otherwise null.
  final String? singleSalahName;
  final String? singleOld12;
  final String? singleNew12;

  /// Heading to display (fixed per spec).
  final String heading;

  /// Subheading per spec: “Starting this {Weekday}, {Month} {D}, {YYYY}”
  final String startingPhrase;

  const IqamahChange({
    required this.changeDate,
    required this.daysToChange,
    required this.fajrChanged,
    required this.dhuhrChanged,
    required this.asrChanged,
    required this.ishaChanged,
    required this.prettyDiffs,
    required this.prettyDiffs12,
    required this.uiLines12,
    required this.isSingleChange,
    required this.singleSalahName,
    required this.singleOld12,
    required this.singleNew12,
    required this.heading,
    required this.startingPhrase,
  });

  bool get anyChange =>
      fajrChanged || dhuhrChanged || asrChanged || ishaChanged;

  /// Useful to emphasize Fajr in the T‑1 sheet (kept for backwards compatibility).
  bool get fajrEmphasis => fajrChanged;

  String get changeYMD => _ymd(changeDate);

  /// Long, user‑friendly date (e.g., "Monday, March 8, 2026").
  String get changeDateLong => _friendlyLongDate(changeDate);

  @override
  String toString() =>
      'changeDate=$changeYMD, Δ=$daysToChange, diffs=$prettyDiffs, diffs12=$prettyDiffs12';
}

class IqamahChangeService {
  /// Toggle verbose logs if needed (e.g., from a debug menu).
  static bool logEnabled = false;

  /// Evening cutoff for the “night‑before” popup (local time).
  /// We deliberately do NOT parse Maghrib—this is a fixed hour:minute gate.
  static int eveningCutoffHour = 19; // 7 PM
  static int eveningCutoffMinute = 0;

  static void _log(String message) {
    if (logEnabled) debugPrint('[IqamahChange] $message');
  }

  /// Main detector: returns the next change as T+1 (Δ=1) or T+2 (Δ=2), or null.
  static IqamahChange? detectUpcomingChange({
    required List<PrayerDay> allDays,
    required DateTime todayLocal,
  }) {
    if (allDays.isEmpty) {
      _log('No days loaded (allDays.isEmpty) — returning null');
      return null;
    }

    DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

    final t0 = dayOnly(todayLocal);
    final t1 = t0.add(const Duration(days: 1));
    final t2 = t0.add(const Duration(days: 2));

    final d0 = _find(allDays, t0);
    final d1 = _find(allDays, t1);
    final d2 = _find(allDays, t2);

    _log('Window: T=${_ymd(t0)}, T+1=${_ymd(t1)}, T+2=${_ymd(t2)} '
        '(found: ${d0 != null}/${d1 != null}/${d2 != null})');

    if (d1 == null) {
      _log('No data for T+1 — returning null');
      return null;
    }

    final s0 = d0 == null ? null : _snap(d0);
    final s1 = _snap(d1);
    final s2 = d2 == null ? null : _snap(d2);

    _log('snap[T]  = ${s0?.toMap() ?? '<none>'}');
    _log('snap[T+1]= ${s1.toMap()}');
    _log('snap[T+2]= ${s2?.toMap() ?? '<none>'}');

    // Case A: Today → Tomorrow differs → change tomorrow (Δ=1)
    if (s0 != null && s0 != s1) {
      final ch = _buildChange(
        changeDate: t1,
        daysToChange: 1,
        from: d0!,
        to: d1,
      );
      _log('Change (T→T+1): $ch');
      return ch;
    }

    // Case B: Tomorrow → Day‑after differs → change day‑after (Δ=2)
    if (s2 != null && s1 != s2) {
      final ch = _buildChange(
        changeDate: t2,
        daysToChange: 2,
        from: d1,
        to: d2!,
      );
      _log('Change (T+1→T+2): $ch');
      return ch;
    }

    _log('No qualifying change within T+1/T+2');
    return null;
  }

  /// Night‑before gate without Maghrib: fixed evening cutoff (default 19:00).
  static bool isAfterEveningCutoff(DateTime nowLocal) {
    final t = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      eveningCutoffHour,
      eveningCutoffMinute,
    );
    final after = nowLocal.isAfter(t) || nowLocal.isAtSameMomentAs(t);
    _log('isAfterEveningCutoff? now=${nowLocal.toLocal()} '
        'cutoff=${t.toLocal()} -> $after');
    return after;
  }

  /// Backward‑compatible alias so main.dart does not need changes.
  /// Internally routes to the fixed evening cutoff.
  static bool isAfterMaghrib({
    required PrayerDay today,
    required DateTime nowLocal,
  }) {
    // Intentionally ignore today's Maghrib time; use fixed cutoff instead.
    return isAfterEveningCutoff(nowLocal);
  }

  // --------------------------- internals ---------------------------

  static PrayerDay? _find(List<PrayerDay> days, DateTime d) {
    for (final x in days) {
      if (x.date.year == d.year &&
          x.date.month == d.month &&
          x.date.day == d.day) {
        return x;
      }
    }
    return null;
  }

  static _IqamahSnapshot _snap(PrayerDay d) {
    String q(String name) => d.prayers[name]?.iqamah ?? '';
    // Only keep Fajr, Dhuhr, Asr, Isha (Maghrib is intentionally omitted)
    return _IqamahSnapshot(
      fajr: q('fajr'),
      dhuhr: q('dhuhr'),
      asr: q('asr'),
      isha: q('isha'),
    );
  }

  /// Returns both 24h and 12h pretty diffs + structured UI lines.
  static ({
  Map<String, String> diffs24,
  Map<String, String> diffs12,
  List<({String label, String old12, String new12})> lines12,
  bool fajrChanged,
  bool dhuhrChanged,
  bool asrChanged,
  bool ishaChanged,
  }) _computeDiffs(PrayerDay from, PrayerDay to) {
    // Helper to fetch IQamah time, default '' if missing
    String t(PrayerDay d, String key) => d.prayers[key]?.iqamah ?? '';

    final labels = const ['Fajr', 'Dhuhr', 'Asr', 'Isha'];
    final keys = const ['fajr', 'dhuhr', 'asr', 'isha'];

    final diffs24 = <String, String>{};
    final diffs12 = <String, String>{};
    final lines12 = <({String label, String old12, String new12})>[];

    bool fajrChanged = false, dhuhrChanged = false, asrChanged = false, ishaChanged = false;

    for (var i = 0; i < labels.length; i++) {
      final label = labels[i];
      final key = keys[i];

      final a = t(from, key);
      final b = t(to, key);

      if (a != b) {
        diffs24[label] = '$a → $b';

        final a12 = _to12h(a);
        final b12 = _to12h(b);
        diffs12[label] = '$a12 → $b12';
        lines12.add((label: label, old12: a12, new12: b12));

        switch (label) {
          case 'Fajr':
            fajrChanged = true;
            break;
          case 'Dhuhr':
            dhuhrChanged = true;
            break;
          case 'Asr':
            asrChanged = true;
            break;
          case 'Isha':
            ishaChanged = true;
            break;
        }
      }
    }

    return (
    diffs24: diffs24,
    diffs12: diffs12,
    lines12: lines12,
    fajrChanged: fajrChanged,
    dhuhrChanged: dhuhrChanged,
    asrChanged: asrChanged,
    ishaChanged: ishaChanged,
    );
  }

  static IqamahChange _buildChange({
    required DateTime changeDate,
    required int daysToChange,
    required PrayerDay from,
    required PrayerDay to,
  }) {
    final diffs = _computeDiffs(from, to);

    // Single vs multi change
    final changedCount = [
      diffs.fajrChanged,
      diffs.dhuhrChanged,
      diffs.asrChanged,
      diffs.ishaChanged,
    ].where((x) => x).length;

    String? singleName;
    String? singleOld12;
    String? singleNew12;

    if (changedCount == 1 && diffs.lines12.isNotEmpty) {
      final only = diffs.lines12.first;
      singleName = only.label;
      singleOld12 = only.old12;
      singleNew12 = only.new12;
    }

    final heading = 'Iqamah Time Change';
    final startingPhrase = 'Starting on ${_friendlyLongDate(changeDate)}';

    return IqamahChange(
      changeDate: changeDate,
      daysToChange: daysToChange,
      fajrChanged: diffs.fajrChanged,
      dhuhrChanged: diffs.dhuhrChanged,
      asrChanged: diffs.asrChanged,
      ishaChanged: diffs.ishaChanged,
      prettyDiffs: diffs.diffs24,
      prettyDiffs12: diffs.diffs12,
      uiLines12: diffs.lines12,
      isSingleChange: changedCount == 1,
      singleSalahName: singleName,
      singleOld12: singleOld12,
      singleNew12: singleNew12,
      heading: heading,
      startingPhrase: startingPhrase,
    );
  }
}