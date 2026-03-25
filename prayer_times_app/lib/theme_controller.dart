// lib/theme_controller.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'ux_prefs.dart';

/// A ValueNotifier that exposes a safe instance method to force a rebuild.
class ThemeModeNotifier extends ValueNotifier<ThemeMode> {
  ThemeModeNotifier(super.value);
  void nudge() => notifyListeners(); // legal: called from instance method
}

/// Central controller for app theming.
///
/// - Restores saved theme mode (if any)
/// - Otherwise adopts system brightness on first launch
/// - Reacts to platform brightness changes when in ThemeMode.system
class ThemeController {
  /// Single source of truth for current theme mode.
  static final ThemeModeNotifier themeMode =
  ThemeModeNotifier(ThemeMode.system);

  /// Latest OS brightness (useful for "effective" theme computations).
  static final ValueNotifier<Brightness> platformBrightness =
  ValueNotifier<Brightness>(
    SchedulerBinding.instance.platformDispatcher.platformBrightness,
  );

  static bool _initialized = false;
  static VoidCallback? _platformListener;

  /// Initialize theme controller.
  /// MUST be awaited before runApp().
  static Future<void> init() async {
    if (_initialized) return;

    // 1) Load saved theme, if any
    final ThemeMode? saved = await UXPrefs.loadThemeMode();
    if (saved != null) {
      themeMode.value = saved;
    } else {
      // 2) No saved pref: adopt the OS at first launch
      final sys =
          SchedulerBinding.instance.platformDispatcher.platformBrightness;
      themeMode.value = (sys == Brightness.dark)
          ? ThemeMode.dark
          : ThemeMode.light;
    }

    // 3) Track platform brightness and propagate rebuilds in system mode
    platformBrightness.value =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;

    _platformListener ??= () {
      final now =
          SchedulerBinding.instance.platformDispatcher.platformBrightness;
      if (platformBrightness.value != now) {
        platformBrightness.value = now;

        // If following system, force listeners to rebuild even if the enum
        // value (ThemeMode.system) itself didn't change.
        if (themeMode.value == ThemeMode.system) {
          themeMode.nudge(); // ✅ legal, instance method
        }
      }
    };

    SchedulerBinding.instance.platformDispatcher.onPlatformBrightnessChanged =
    _platformListener!;
    _initialized = true;
  }

  /// Programmatically change the theme mode and persist it.
  static Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode.value == mode) return;
    themeMode.value = mode;
    await UXPrefs.saveThemeMode(mode);
  }

  /// Helpers
  static bool get isDarkEffective {
    final mode = themeMode.value;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return platformBrightness.value == Brightness.dark;
  }

  static Brightness get effectiveBrightness =>
      isDarkEffective ? Brightness.dark : Brightness.light;
}