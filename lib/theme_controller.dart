// lib/theme_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'ux_prefs.dart';

/// Central controller for app theming.
/// - Restores saved theme mode (if any)
/// - Otherwise uses system brightness at first launch
/// - Reacts to platform brightness changes when in ThemeMode.system
class ThemeController {
  /// Single source of truth for current theme mode.
  static final ValueNotifier<ThemeMode> themeMode =
  ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Tracks current platform brightness so widgets can compute effective theme.
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

    // 1) Load saved theme, if the app persisted one.
    final ThemeMode? saved = await UXPrefs.loadThemeMode();

    if (saved != null) {
      themeMode.value = saved;
    } else {
      // 2) No saved preference: adopt the OS at first launch
      final sys = SchedulerBinding.instance.platformDispatcher.platformBrightness;
      themeMode.value = (sys == Brightness.dark) ? ThemeMode.dark : ThemeMode.light;
    }

    // 3) Keep track of platform brightness for System mode + UI that needs it
    platformBrightness.value =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;

    // Attach a listener so we react to OS theme changes when in system mode
    _platformListener ??= () {
      final now = SchedulerBinding.instance.platformDispatcher.platformBrightness;
      if (platformBrightness.value != now) {
        platformBrightness.value = now;

        // Only propagate a rebuild when following the system.
        if (themeMode.value == ThemeMode.system) {
          // Nudge listeners by re-setting same mode (causes rebuilds that depend on it)
          themeMode.notifyListeners();
        }
      }
    };

    SchedulerBinding.instance.platformDispatcher.onPlatformBrightnessChanged
    = _platformListener!;

    _initialized = true;
  }

  /// Programmatically change the theme mode and persist it.
  static Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode.value == mode) return;
    themeMode.value = mode;
    await UXPrefs.saveThemeMode(mode);
  }

  /// Convenience helpers
  static bool get isDarkEffective {
    final mode = themeMode.value;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return platformBrightness.value == Brightness.dark;
  }

  static Brightness get effectiveBrightness =>
      isDarkEffective ? Brightness.dark : Brightness.light;
}
