// lib/ux_prefs.dart

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class UXPrefs {
  static SharedPreferences? _sp;

  // -----------------------
  // EXISTING PREF KEYS
  // -----------------------
  static const _kHaptics = 'ux.haptics';
  static const _kTextScale = 'ux.textScale';

  // -----------------------
  // NEW THEME PREF KEY
  // -----------------------
  static const _kThemeMode = 'ux.themeMode';

  /// Haptics is OFF by default until the user enables it.
  static final ValueNotifier<bool> hapticsEnabled =
  ValueNotifier<bool>(false);

  /// Global text scale (1.0 default).
  static final ValueNotifier<double> textScale =
  ValueNotifier<double>(1.0);

  // --------------------------------------------------------------
  // INIT
  // --------------------------------------------------------------
  static Future<void> init() async {
    _sp ??= await SharedPreferences.getInstance();

    // Load existing prefs
    final he = _sp!.getBool(_kHaptics) ?? false;
    final ts = _sp!.getDouble(_kTextScale) ?? 1.0;

    hapticsEnabled.value = he;
    textScale.value = ts;
  }

  // --------------------------------------------------------------
  // HAPTICS
  // --------------------------------------------------------------
  static Future<void> setHapticsEnabled(bool v) async {
    hapticsEnabled.value = v;
    await _sp?.setBool(_kHaptics, v);

    if (v) {
      // Play a subtle tap only if user turned it ON
      HapticFeedback.lightImpact();
    }
  }

  // --------------------------------------------------------------
  // TEXT SCALE
  // --------------------------------------------------------------
  static Future<void> setTextScale(double scale) async {
    textScale.value = scale;
    await _sp?.setDouble(_kTextScale, scale);
  }

  /// One safe place to call a haptic, guarded by the toggle.
  static void maybeHaptic() {
    if (hapticsEnabled.value) HapticFeedback.lightImpact();
  }

  /// Map label → scale
  static double scaleForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'small':
        return 0.92;
      case 'large':
        return 1.12;
      default:
        return 1.0; // 'Default'
    }
  }

  /// Map scale → label
  static String labelForScale(double scale) {
    if (scale <= 0.95) return 'Small';
    if (scale >= 1.08) return 'Large';
    return 'Default';
  }

  // --------------------------------------------------------------
  // NEW THEME MODE PERSISTENCE
  // --------------------------------------------------------------

  /// Load saved theme mode.
  ///
  /// Returns:
  ///   - ThemeMode.light
  ///   - ThemeMode.dark
  ///   - ThemeMode.system
  ///   - null  → no saved choice (first launch)
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

  /// Save theme mode selection persistently.
  static Future<void> saveThemeMode(ThemeMode mode) async {
    _sp ??= await SharedPreferences.getInstance();
    String value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _sp!.setString(_kThemeMode, value);
  }
}