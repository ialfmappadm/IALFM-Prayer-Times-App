
// lib/models/announcement.dart
import 'package:timezone/timezone.dart' as tz;

class Announcement {
  final String id;
  final String title;
  final String body;

  /// Store canonical timestamp in UTC to avoid ambiguity.
  final DateTime publishedAtUtc;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAtUtc,
  });

  /// Convert to Central Time (America/Chicago) when you need to show it.
  tz.TZDateTime publishedAtCentral({tz.Location? location}) {
    final loc = location ?? tz.getLocation('America/Chicago');
    return tz.TZDateTime.from(publishedAtUtc, loc);
  }

  factory Announcement.fromJson(Map<String, dynamic> j) {
    DateTime parseUtc(dynamic v) {
      if (v == null) return DateTime.now().toUtc();

      if (v is int) {
        // If 13 digits treat as milliseconds; if 10 digits treat as seconds.
        final isMs = v > 100000000000; // heuristic
        return DateTime.fromMillisecondsSinceEpoch(isMs ? v : v * 1000, isUtc: true);
      }

      final s = v.toString();
      final dt = DateTime.tryParse(s);
      if (dt != null) return dt.toUtc(); // normalize regardless of provided offset
      return DateTime.now().toUtc();
    }

    return Announcement(
      id: j['id']?.toString() ?? '',
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      publishedAtUtc: parseUtc(j['published_at']),
    );
  }
}