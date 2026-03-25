// lib/utils/clock_skew.dart
import 'dart:io' show HttpDate;
import 'package:http/http.dart' as http;

/// App-session clock skew (server_utc - device_utc).
/// Calibrate once via HTTP Date header; if it fails, skew stays zero.
class ClockSkew {
  static Duration _skew = Duration.zero;
  static Duration get skew => _skew;

  static Future<void> calibrate() async {
    try {
      // Fast HEAD that returns a reliable RFC‑7231 Date header.
      final resp = await http
          .head(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 4));
      final dateHdr = resp.headers['date'];
      if (dateHdr == null) return;

      final serverUtc = HttpDate.parse(dateHdr); // UTC
      final deviceUtc = DateTime.now().toUtc();
      _skew = serverUtc.difference(deviceUtc);
    } catch (_) {
      // Offline / blocked → leave skew at 0.
    }
  }
}