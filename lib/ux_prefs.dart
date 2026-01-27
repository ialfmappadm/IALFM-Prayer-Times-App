
// lib/ux_prefs.dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UXPrefs {
  static SharedPreferences? _sp;

  static const _kHaptics   = 'ux.haptics';
  static const _kTextScale = 'ux.textScale';

  /// Haptics is OFF by default until the user enables it.
  static final ValueNotifier<bool> hapticsEnabled = ValueNotifier<bool>(false);

  /// Global text scale (1.0 default). We’ll map Small/Default/Large to numbers below.
  static final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  static Future<void> init() async {
    _sp ??= await SharedPreferences.getInstance();
    final he = _sp!.getBool(_kHaptics) ?? false;      // default OFF
    final ts = _sp!.getDouble(_kTextScale) ?? 1.0;    // default 1.0
    hapticsEnabled.value = he;
    textScale.value = ts;
  }

  static Future<void> setHapticsEnabled(bool v) async {
    hapticsEnabled.value = v;
    await _sp?.setBool(_kHaptics, v);
    if (v) {
      // Play a subtle tap only if user turned it ON
      HapticFeedback.lightImpact();
    }
  }

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
      case 'small':   return 0.92;
      case 'large':   return 1.12;
      default:        return 1.0; // 'Default'
    }
  }

  /// Map scale → label
  static String labelForScale(double scale) {
    if (scale <= 0.95) return 'Small';
    if (scale >= 1.08) return 'Large';
    return 'Default';
  }
}