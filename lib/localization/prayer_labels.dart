
// lib/localization/prayer_labels.dart
import 'package:flutter/widgets.dart';

/// Returns Arabic labels when the current app locale is 'ar',
/// otherwise returns the original English labels.
/// No layout/direction changes here—just strings.
class PrayerLabels {
  static bool _isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  // Column headers
  static String colSalah(BuildContext c)  => _isArabic(c) ? 'الصلاة'  : 'Salah';
  static String colAdhan(BuildContext c)  => _isArabic(c) ? 'الأذان'   : 'Adhan';
  static String colIqamah(BuildContext c) => _isArabic(c) ? 'الإقامة'  : 'Iqamah';

  // Individual prayer names (case-insensitive)
  static String prayerName(BuildContext c, String englishName) {
    if (!_isArabic(c)) return englishName;
    switch (englishName.toLowerCase()) {
      case 'fajr':     return 'الفجر';
      case 'sunrise':  return 'الشروق';
      case 'dhuhr':    return 'الظهر';
      case 'asr':      return 'العصر';
      case 'maghrib':  return 'المغرب';
      case 'isha':     return 'العشاء';
      case "jumu'ah":
      case 'jumuah':
      case "jummua'h":
      case 'jummah':   return 'الجمعة';
      default:         return englishName;
    }
  }

  /// Countdown header, driven by the *actual* next prayer key:
  ///   en -> "Maghrib Adhan in"
  ///   ar -> "اذان المغرب في"
  ///
  /// Accepts 'fajr','dhuhr','asr','maghrib','isha' (any case).
  static String countdownHeader(BuildContext c, String nextPrayerKey) {
    final isAr = _isArabic(c);
    final key = nextPrayerKey.toLowerCase();
    if (isAr) {
      switch (key) {
        case 'fajr':     return 'اذان الفجر في';
        case 'dhuhr':    return 'اذان الظهر في';
        case 'asr':      return 'اذان العصر في';
        case 'maghrib':  return 'اذان المغرب في';
        case 'isha':     return 'اذان العشاء في';
        default:         return 'الاذان في';
      }
    }
    final cap = key.isEmpty ? '' : key[0].toUpperCase() + key.substring(1);
    return '$cap Adhan in';
  }
}
