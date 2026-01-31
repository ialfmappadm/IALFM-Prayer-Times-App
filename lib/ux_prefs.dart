// lib/ux_prefs.dart
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UXPrefs {
  static SharedPreferences? _sp;

  // ── Keys (existing) ────────────────────────────────────────────────────────
  static const _kHaptics       = 'ux.haptics';
  static const _kTextScale     = 'ux.textScale';
  static const _kThemeMode     = 'ux.themeMode';
  static const _kUse24h        = 'ux.use24h';
  static const _kHijriOffset   = 'ux.hijriOffset';
  static const _kHijriBaseAdjust = 'ux.hijriBaseAdjust';

  // ── NEW: Notification toggles ──────────────────────────────────────────────
  static const _kAdhanAlertEnabled   = 'ux.alerts.adhanEnabled';
  static const _kIqamahAlertEnabled  = 'ux.alerts.iqamahEnabled';
  static const _kJumuahReminderEnabled = 'ux.alerts.jumuahEnabled';

  // ── Notifiers (existing) ──────────────────────────────────────────────────
  static final ValueNotifier<bool>   hapticsEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<double> textScale      = ValueNotifier<double>(1.0);
  static final ValueNotifier<bool>   use24h         = ValueNotifier<bool>(false);
  /// User-controlled offset (−1..+1)
  static final ValueNotifier<int>    hijriOffset    = ValueNotifier<int>(0);
  /// Internal base adjustment set by override service (e.g., −1..+1)
  static final ValueNotifier<int>    hijriBaseAdjust = ValueNotifier<int>(0);

  // ── NEW: Notifiers for notification toggles ───────────────────────────────
  static final ValueNotifier<bool> adhanAlertEnabled    = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> iqamahAlertEnabled   = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> jumuahReminderEnabled= ValueNotifier<bool>(false);

  static Future<void> init() async {
    _sp ??= await SharedPreferences.getInstance();
    // Existing prefs
    hapticsEnabled.value   = _sp!.getBool(_kHaptics)       ?? false;
    textScale.value        = _sp!.getDouble(_kTextScale)   ?? 1.0;
    use24h.value           = _sp!.getBool(_kUse24h)        ?? false;
    hijriOffset.value      = _sp!.getInt(_kHijriOffset)    ?? 0;
    hijriBaseAdjust.value  = _sp!.getInt(_kHijriBaseAdjust)?? 0;

    // NEW: Load notification toggles
    adhanAlertEnabled.value     = _sp!.getBool(_kAdhanAlertEnabled)    ?? false;
    iqamahAlertEnabled.value    = _sp!.getBool(_kIqamahAlertEnabled)   ?? false;
    jumuahReminderEnabled.value = _sp!.getBool(_kJumuahReminderEnabled)?? false;
  }

  // ── Existing setters ──────────────────────────────────────────────────────
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
      case 'small': return 0.92;
      case 'large': return 1.12;
      default: return 1.0;
    }
  }

  static String labelForScale(double scale) {
    if (scale <= 0.95) return 'Small';
    if (scale >= 1.08) return 'Large';
    return 'Default';
  }

  // Theme mode persistence
  static Future<ThemeMode?> loadThemeMode() async {
    _sp ??= await SharedPreferences.getInstance();
    final raw = _sp!.getString(_kThemeMode);
    switch (raw) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      case 'system': return ThemeMode.system;
      default: return null;
    }
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    _sp ??= await SharedPreferences.getInstance();
    late final String raw;
    switch (mode) {
      case ThemeMode.light:  raw = 'light';  break;
      case ThemeMode.dark:   raw = 'dark';   break;
      case ThemeMode.system: raw = 'system'; break;
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

  /// Effective total offset (base from override + user choice)
  static int get hijriEffectiveOffset => hijriBaseAdjust.value + hijriOffset.value;

  // ── NEW: Setters for notification toggles ─────────────────────────────────
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
}