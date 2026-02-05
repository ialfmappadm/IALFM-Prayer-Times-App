// lib/ux_prefs.dart
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UXPrefs {
  static SharedPreferences? _sp;

  // Existing keys
  static const _kHaptics = 'ux.haptics';
  static const _kTextScale = 'ux.textScale';
  static const _kThemeMode = 'ux.themeMode';
  static const _kUse24h = 'ux.use24h';
  static const _kHijriOffset = 'ux.hijriOffset';
  static const _kHijriBaseAdjust = 'ux.hijriBaseAdjust';

  // Notification toggles (existing)
  static const _kAdhanAlertEnabled = 'ux.alerts.adhanEnabled';
  static const _kIqamahAlertEnabled = 'ux.alerts.iqamahEnabled';
  static const _kJumuahReminderEnabled = 'ux.alerts.jumuahEnabled';

  // NEW: return-to-tab intent (used to restore More tab after OS Settings)
  static const _kLastIntendedTab = 'ux.lastIntendedTab';

  // NEW: Iqamah-change prompt tracking
  static const _kHeadsUpShownSet = 'ux.changeAlert.headsUpShownSet';
  static const _kNightBeforeShownSet = 'ux.changeAlert.nightBeforeShownSet';
  static const _kLastOpenYMD = 'ux.lastOpenYMD';

  static Set<String> _headsUpShown = <String>{};
  static Set<String> _nightBeforeShown = <String>{};

  // Notifiers (existing)
  static final ValueNotifier<bool> hapticsEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);
  static final ValueNotifier<bool> use24h = ValueNotifier<bool>(false);
  static final ValueNotifier<int> hijriOffset = ValueNotifier<int>(0);
  static final ValueNotifier<int> hijriBaseAdjust = ValueNotifier<int>(0);

  // Toggles (existing)
  static final ValueNotifier<bool> adhanAlertEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> iqamahAlertEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> jumuahReminderEnabled = ValueNotifier<bool>(false);

  static Future<void> init() async {
    _sp ??= await SharedPreferences.getInstance();

    // existing
    hapticsEnabled.value = _sp!.getBool(_kHaptics) ?? false;
    textScale.value = _sp!.getDouble(_kTextScale) ?? 1.0;
    use24h.value = _sp!.getBool(_kUse24h) ?? false;
    hijriOffset.value = _sp!.getInt(_kHijriOffset) ?? 0;
    hijriBaseAdjust.value = _sp!.getInt(_kHijriBaseAdjust) ?? 0;

    // toggles
    adhanAlertEnabled.value = _sp!.getBool(_kAdhanAlertEnabled) ?? false;
    iqamahAlertEnabled.value = _sp!.getBool(_kIqamahAlertEnabled) ?? false;
    jumuahReminderEnabled.value = _sp!.getBool(_kJumuahReminderEnabled) ?? false;

    // sets
    _headsUpShown = (_sp!.getStringList(_kHeadsUpShownSet) ?? const <String>[]).toSet();
    _nightBeforeShown = (_sp!.getStringList(_kNightBeforeShownSet) ?? const <String>[]).toSet();
  }

  // existing setters
  static Future<void> setHapticsEnabled(bool v) async {
    hapticsEnabled.value = v;
    await _sp?.setBool(_kHaptics, v);
    if (v) HapticFeedback.lightImpact();
  }

  static Future<void> setTextScale(double scale) async {
    textScale.value = scale;
    await _sp?.setDouble(_kTextScale, scale);
  }

  static void maybeHaptic() {
    if (hapticsEnabled.value) HapticFeedback.lightImpact();
  }

  static double scaleForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'small':
        return 0.92;
      case 'large':
        return 1.12;
      default:
        return 1.0;
    }
  }

  static String labelForScale(double scale) {
    if (scale <= 0.95) return 'Small';
    if (scale >= 1.08) return 'Large';
    return 'Default';
  }

  // Theme mode
  static Future<ThemeMode?> loadThemeMode() async {
    _sp ??= await SharedPreferences.getInstance();
    final raw = _sp!.getString(_kThemeMode);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    _sp ??= await SharedPreferences.getInstance();
    late final String raw;
    switch (mode) {
      case ThemeMode.light:
        raw = 'light';
        break;
      case ThemeMode.dark:
        raw = 'dark';
        break;
      case ThemeMode.system:
        raw = 'system';
        break;
    }
    await _sp!.setString(_kThemeMode, raw);
  }

  // 12/24h
  static Future<void> setUse24h(bool v) async {
    use24h.value = v;
    await _sp?.setBool(_kUse24h, v);
  }

  // Hijri offsets
  static Future<void> setHijriOffset(int days) async {
    final clamped = days.clamp(-1, 1);
    hijriOffset.value = clamped;
    await _sp?.setInt(_kHijriOffset, clamped);
  }

  static Future<void> setHijriBaseAdjust(int days) async {
    final clamped = days.clamp(-2, 2);
    hijriBaseAdjust.value = clamped;
    await _sp?.setInt(_kHijriBaseAdjust, clamped);
  }

  static int get hijriEffectiveOffset => hijriBaseAdjust.value + hijriOffset.value;

  // Toggle setters
  static Future<void> setAdhanAlertEnabled(bool v) async {
    adhanAlertEnabled.value = v;
    await _sp?.setBool(_kAdhanAlertEnabled, v);
  }

  static Future<void> setIqamahAlertEnabled(bool v) async {
    iqamahAlertEnabled.value = v;
    await _sp?.setBool(_kIqamahAlertEnabled, v);
  }

  static Future<void> setJumuahReminderEnabled(bool v) async {
    jumuahReminderEnabled.value = v;
    await _sp?.setBool(_kJumuahReminderEnabled, v);
  }

  // NEW: return-to-tab helpers (used to restore 'More' after OS Settings)
  static Future<void> setLastIntendedTab(String? tab) async {
    await setString(_kLastIntendedTab, tab);
  }

  static Future<String?> getLastIntendedTab() async {
    return getString(_kLastIntendedTab);
  }

  // NEW: “first open of the day” helper
  static Future<bool> markOpenToday(DateTime nowLocal) async {
    _sp ??= await SharedPreferences.getInstance();
    final ymd = _ymd(nowLocal);
    final prev = _sp!.getString(_kLastOpenYMD);
    if (prev == ymd) return false;
    await _sp!.setString(_kLastOpenYMD, ymd);
    return true;
  }

  // NEW: one‑shot guards per change date (YYYY‑MM‑DD)
  static bool wasShownHeadsUp(String ymd) => _headsUpShown.contains(ymd);
  static Future<void> markShownHeadsUp(String ymd) async {
    _headsUpShown.add(ymd);
    await _sp?.setStringList(_kHeadsUpShownSet, _headsUpShown.toList());
  }

  static bool wasShownNightBefore(String ymd) => _nightBeforeShown.contains(ymd);
  static Future<void> markShownNightBefore(String ymd) async {
    _nightBeforeShown.add(ymd);
    await _sp?.setStringList(_kNightBeforeShownSet, _nightBeforeShown.toList());
  }

  // NEW: tiny KV helpers used for announcement “version” / “payload”
  static Future<String?> getString(String key) async {
    _sp ??= await SharedPreferences.getInstance();
    return _sp!.getString(key);
  }

  static Future<void> setString(String key, String? value) async {
    _sp ??= await SharedPreferences.getInstance();
    if (value == null) {
      await _sp!.remove(key);
    } else {
      await _sp!.setString(key, value);
    }
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}