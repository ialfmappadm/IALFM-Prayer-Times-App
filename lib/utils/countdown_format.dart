// lib/utils/countdown_format.dart

/// Countdown styles (no days; you said diffs never exceed 24h).
enum CountdownStyle {
  /// Original long words: "2 hr 5 min", "42 sec"
  longWords,

  /// Compact with units (recommended compact): "2h 5m", "42s"
  unitsLower,

  /// Compact with UPPER units: "2H 5M", "42S"
  unitsUpper,

  /// Colon, no units (clock-like minutes when < 1h): "2:05", seconds still "42s"
  colonNoUnits,

  /// Colon + units: "2h:05m", "42s"
  colonUnitsLower,

  /// Thin dot separator: "2h·5m", "42s"
  dotUnits,

  /// Digital clock (your original): "HH:MM:SS" — always shows seconds
  digitalHms,

  /// Digital HH:MM (no seconds): "HH:MM"
  digitalHm,
}

/// Single toggle: pick the style you want before shipping.
// Choose ONE:
//const CountdownStyle kCountdownStyle = CountdownStyle.digitalHms; // "HH:MM:SS" (original)
//const CountdownStyle kCountdownStyle = CountdownStyle.digitalHm;  // "HH:MM"
//const CountdownStyle kCountdownStyle = CountdownStyle.unitsLower; // "2h 5m", "42s"
//const CountdownStyle kCountdownStyle = CountdownStyle.longWords;  // "2 hr 5 min", "42 sec"
//const CountdownStyle kCountdownStyle = CountdownStyle.colonNoUnits;    // "2:05", "42s"
//const CountdownStyle kCountdownStyle = CountdownStyle.colonUnitsLower; // "2h:05m", "42s"
//const CountdownStyle kCountdownStyle = CountdownStyle.dotUnits;        // "2h·5m", "42s"
const CountdownStyle kCountdownStyle = CountdownStyle.digitalHms;

/// Top-level entry point used by the app.
String formatCountdownStyled(
    Duration d, {
      CountdownStyle? style,
      bool zeroPadMinutesForColon = true, // 2:05 instead of 2:5 in colon styles
    }) {
  final st = style ?? kCountdownStyle;

  // Normalized parts (0–23h, 0–59m, 0–59s; negatives clamp to zero)
  final totalSec = d.inSeconds <= 0 ? 0 : d.inSeconds;
  final h = totalSec ~/ 3600;
  final rem = totalSec % 3600;
  final m = rem ~/ 60;
  final s = rem % 60;

  String two(int n) => n.toString().padLeft(2, '0');

  switch (st) {
    case CountdownStyle.digitalHms:
    // HH:MM:SS (always)
      return '${two(h)}:${two(m)}:${two(s)}';

    case CountdownStyle.digitalHm:
    // HH:MM (always; seconds suppressed)
      return '${two(h)}:${two(m)}';

    case CountdownStyle.longWords:
      if (totalSec < 60) return '$s sec';
      if (h == 0) return '$m min';
      return '$h hr $m min';

    case CountdownStyle.unitsLower:
      if (totalSec < 60) return '${s}s';
      if (h == 0) return '${m}m';
      return '${h}h ${m}m';

    case CountdownStyle.unitsUpper:
      if (totalSec < 60) return '${s}S';
      if (h == 0) return '${m}M';
      return '${h}H ${m}M';

    case CountdownStyle.colonNoUnits:
      if (totalSec < 60) return '${s}s';
      if (h == 0) return '$m';
      final mm = zeroPadMinutesForColon ? two(m) : '$m';
      return '$h:$mm';

    case CountdownStyle.colonUnitsLower:
      if (totalSec < 60) return '${s}s';
      if (h == 0) return '${m}m';
      final mm = zeroPadMinutesForColon ? two(m) : '$m';
      return '${h}h:${mm}m';

    case CountdownStyle.dotUnits:
      if (totalSec < 60) return '${s}s';
      if (h == 0) return '${m}m';
      return '${h}h\u00B7${m}m'; // \u00B7 = middle dot
  }
}