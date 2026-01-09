
// lib/models/announcement.dart
class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime publishedAt;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) {
    return Announcement(
      id: j['id'].toString(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      publishedAt: DateTime.tryParse((j['published_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
