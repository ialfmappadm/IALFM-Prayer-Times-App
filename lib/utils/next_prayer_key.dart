
/// Returns the next prayer key in: fajr, dhuhr, asr, maghrib, isha.
/// Assumes you already have the adhan DateTimes for today (and optional Fajr tomorrow).
String nextPrayerKey({
  required DateTime nowLocal,
  required DateTime fajr,
  required DateTime dhuhr,
  required DateTime asr,
  required DateTime maghrib,
  required DateTime isha,
  DateTime? fajrTomorrow,
}) {
  final items = <MapEntry<String, DateTime>>[
    MapEntry('fajr', fajr),
    MapEntry('dhuhr', dhuhr),
    MapEntry('asr', asr),
    MapEntry('maghrib', maghrib),
    MapEntry('isha', isha),
  ];
  for (final e in items) {
    if (nowLocal.isBefore(e.value)) return e.key;
  }
  // If all for today passed, return Fajr of tomorrow when provided; otherwise fallback to Fajr.
  return (fajrTomorrow != null && nowLocal.isBefore(fajrTomorrow))
      ? 'fajr'
      : 'fajr';
}
