// lib/utils/haptics.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ux_prefs.dart';

abstract class Haptics {
  static void tap() {
    if (!UXPrefs.hapticsEnabled.value) return;
    HapticFeedback.lightImpact();
  }

  static void toggle() {
    if (!UXPrefs.hapticsEnabled.value) return;
    HapticFeedback.mediumImpact();
  }

  static void success() {
    if (!UXPrefs.hapticsEnabled.value) return;
    HapticFeedback.selectionClick();
  }

  static void warn() {
    if (!UXPrefs.hapticsEnabled.value) return;
    HapticFeedback.heavyImpact();
  }
}

class HapticNavigatorObserver extends NavigatorObserver {
  HapticNavigatorObserver(); // ← non-const

  @override
  void didPush(Route route, Route? previousRoute) {
    Haptics.tap();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    Haptics.tap();
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    Haptics.tap();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
