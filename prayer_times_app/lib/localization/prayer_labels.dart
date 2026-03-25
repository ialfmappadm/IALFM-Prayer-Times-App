// lib/localization/prayer_labels.dart
import 'package:flutter/widgets.dart';

/// Returns Arabic labels when the current app locale is 'ar',
/// otherwise returns the original English labels. No layout changes—just strings.
class PrayerLabels {
  static bool _isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  static String colSalah(BuildContext c) => _isArabic(c) ? 'الصلاة' : 'Salah';
  static String colAdhan(BuildContext c) => _isArabic(c) ? 'الأذان' : 'Adhan';
  static String colIqamah(BuildContext c) => _isArabic(c) ? 'الإقامة' : 'Iqamah';

  /// Accepts many spellings; returns a canonical token for display mapping.
  static String _normalizeKey(String name) {
    final k = name.trim().toLowerCase();

    switch (k) {
      case 'fajr': return 'fajr';
      case 'sunrise': return 'sunrise';
      case 'dhuhr': return 'dhuhr';
      case 'asr': return 'asr';
      case 'maghrib': return 'maghrib';
      case 'isha': return 'isha';

    // Jumu'ah variants
      case "jumu'ah":
      case 'jumuah':
      case 'jummah':
      case "jummu'ah":
      case "jummuah":
      case "jummua'h":
        return "jumu'ah";

    // Youth Jumu'ah (variants)
      case "youth jumu'ah":
      case 'youth jumuah':
      case 'youth jummah':
      case 'youth-jumuah':
      case 'youth_jumuah':
        return "youth jumu'ah";

      default:
        return k;
    }
  }

  /// Display name mapping (EN/AR). Unknown names fall back to input.
  static String prayerName(BuildContext c, String englishName) {
    final canon = _normalizeKey(englishName);

    if (!_isArabic(c)) {
      // English display casing
      if (canon == "jumu'ah") return "Jumu'ah";
      if (canon == "youth jumu'ah") return "Youth Jumu'ah";
      return englishName;
    }

    // Arabic display mapping
    switch (canon) {
      case 'fajr': return 'الفجر';
      case 'sunrise': return 'الشروق';
      case 'dhuhr': return 'الظهر';
      case 'asr': return 'العصر';
      case 'maghrib': return 'المغرب';
      case 'isha': return 'العشاء';
      case "jumu'ah": return 'الجمعة';
      case "youth jumu'ah": return 'جمعة الشباب';
      default: return englishName;
    }
  }

  /// Banner header; unchanged, but left here for completeness.
  static String countdownHeader(BuildContext c, String nextPrayerKey) {
    final isAr = _isArabic(c);
    final key = _normalizeKey(nextPrayerKey);
    if (isAr) {
      switch (key) {
        case 'fajr': return ': اذان الفجر الساعة';
        case 'dhuhr': return ': اذان الظهر الساعة';
        case 'asr': return ': اذان العصر الساعة';
        case 'maghrib': return ': اذان المغرب الساعة';
        case 'isha': return ': اذان العشاء الساعة';
        default: return ': الأذان الساعة';
      }
    }
    String cap(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
    final display = cap(key);
    return '$display Adhan in';
  }
}
