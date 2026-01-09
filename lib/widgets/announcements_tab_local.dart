
// lib/widgets/announcements_tab_local.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// Make sure this file exists and defines class Announcement
import '../models/announcement.dart';

class AnnouncementsTabLocal extends StatefulWidget {
  final String assetPath; // e.g., 'assets/announcements.json'

  AnnouncementsTabLocal({super.key, required this.assetPath});

  @override
  State<AnnouncementsTabLocal> createState() => _AnnouncementsTabLocalState();
}

class _AnnouncementsTabLocalState extends State<AnnouncementsTabLocal> {
  late Future<List<Announcement>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadFromAssets();
  }

  Future<List<Announcement>> _loadFromAssets() async {
    try {
      final text = await rootBundle.loadString(widget.assetPath);
      final data = jsonDecode(text);
      final list = (data as List)
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.publishedAt.compareTo(a.publishedAt)); // newest first
      return list;
    } catch (e) {
      debugPrint('Local announcements load error: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<Announcement>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No announcements available.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() { _future = _loadFromAssets(); });
              await _future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final a = items[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(a.body, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _formatTimestamp(a.publishedAt),
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime d) {
    const w = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final wd = w[d.weekday - 1];
    final mo = m[d.month - 1];
    int h = d.hour % 12; if (h == 0) h = 12;
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '$wd, $mo ${d.day} ${d.year}  $h:$mm $ap';
  }
}
