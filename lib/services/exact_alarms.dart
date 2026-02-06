// lib/services/exact_alarms.dart
import 'dart:io' show Platform;
import 'package:flutter/services.dart';

const _channel = MethodChannel('org.ialfm.prayertimes/exact_alarms');

Future<void> openExactAlarmsSettings() async {
  if (!Platform.isAndroid) return;
  try {
    await _channel.invokeMethod('openExactAlarmsSettings');
  } catch (_) {
    // No-op; user can navigate manually if needed
  }
}