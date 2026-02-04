// lib/services/time_format_cache.dart
//
// Lightweight memoized time-formatting helpers.
// - Caches DateFormat by (localeTag + pattern)
// - Converts UTC -> America/Chicago safely (fallback: device local)
// - Locale invalidation hook for didChangeDependencies()

import 'dart:collection';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class TimeFormatCache {
  TimeFormatCache._();
  static final instance = TimeFormatCache._();

  String _localeTag = 'en';
  final Map<String, DateFormat> _fmts = HashMap();
  tz.Location? _central;

  /// Call from didChangeDependencies() when locale changes.
  void setLocale(Locale locale) {
    final tag = locale.toLanguageTag();
    if (tag == _localeTag) return;
    _localeTag = tag;
    _fmts.clear(); // invalidate patterns for the new locale
  }

  /// Formats a UTC instant as Central Time (America/Chicago) with a pattern.
  /// Default pattern matches your current label UX.
  String formatCentral(
      DateTime utc, {
        String pattern = 'EEE, MMM d • h:mm a',
        String suffix = 'CT',
      }) {
    final dt = _toCentral(utc.toUtc());
    final fmt = _get(pattern);
    return '${fmt.format(dt)} $suffix';
  }

  // ---- internal -------------------------------------------------------------

  DateTime _toCentral(DateTime utc) {
    try {
      _central ??= tz.getLocation('America/Chicago');
      return tz.TZDateTime.from(utc, _central!);
    } catch (_) {
      // tz database not ready: degrade gracefully to device local
      return utc.toLocal();
    }
  }

  DateFormat _get(String pattern) {
    final key = '$_localeTag::$pattern';
    final cached = _fmts[key];
    if (cached != null) return cached;
    final fmt = DateFormat(pattern, _localeTag);
    _fmts[key] = fmt;
    return fmt;
  }
}