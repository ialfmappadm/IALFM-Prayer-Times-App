
// lib/theme_controller.dart
import 'package:flutter/material.dart';

/// Tiny theme controller for app-wide ThemeMode switching without
/// pulling in state-management packages.
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> themeMode =
  ValueNotifier<ThemeMode>(ThemeMode.system);

  static void setThemeMode(ThemeMode mode) => themeMode.value = mode;
}