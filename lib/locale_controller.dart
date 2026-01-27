import 'package:flutter/material.dart';

/// App-wide locale controller to switch languages at runtime.
///
/// Use:
///   LocaleController.setLocale(const Locale('ar')); // Arabic
///   LocaleController.setLocale(const Locale('en')); // English
class LocaleController {
  static final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  static void setLocale(Locale? value) {
    locale.value = value;
  }
}
