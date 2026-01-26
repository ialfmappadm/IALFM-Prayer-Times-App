import 'package:flutter/material.dart';

/// Simple app-wide locale controller.
class LocaleController {
  static final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  static void setLocale(Locale? value) {
    locale.value = value;
  }
}
