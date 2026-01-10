
// lib/widgets/announcements_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class AnnouncementsTab extends StatefulWidget {
  const AnnouncementsTab({super.key});

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> with WidgetsBindingObserver {
  String _title = 'Announcement';
  String _text = '';
  bool _active = false;
  DateTime? _publishedAt;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRemoteConfig();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(); // auto refresh on resume
    }
  }

  // ---- Remote Config helpers ----
  void _readAndLogRemoteConfig(FirebaseRemoteConfig rc) {
    final active = rc.getBool('announcement_active');
    final titleRaw = rc.getString('announcement_title').trim();
    final textRaw  = rc.getString('announcement_text').trim();
    final publishedRaw = rc.getString('announcement_published_at').trim();

    final parsedWhen = _parsePublishedAt(publishedRaw);

    debugPrint('RC values -> active=$active, '
        'title="$titleRaw", text="$textRaw", published_at="$publishedRaw"');

    setState(() {
      _active = active;
      _title = titleRaw.isEmpty ? 'Announcement' : titleRaw;
      _text = textRaw;
      _publishedAt = parsedWhen;
    });
  }

  DateTime? _parsePublishedAt(String raw) {
    if (raw.isEmpty) return null;

    // 1) Try ISO-8601 (e.g., 2026-03-10T18:30:00-06:00)
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    // 2) Try numeric epoch (seconds or milliseconds)
    final digits = RegExp(r'^\d{10,13}$');
    if (digits.hasMatch(raw)) {
      try {
        final n = int.parse(raw);
        // 13 digits -> ms, 10 digits -> sec
        if (raw.length == 13) {
          return DateTime.fromMillisecondsSinceEpoch(n);
        } else if (raw.length == 10) {
          return DateTime.fromMillisecondsSinceEpoch(n * 1000);
        }
      } catch (_) {}
    }
    return null;
  }

  String _formatTimestamp(DateTime d) {
    // Simple, locale-agnostic formatter to avoid extra dependencies.
    const w = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final wd = w[d.weekday - 1];
    final mo = m[d.month - 1];
    int h = d.hour % 12; if (h == 0) h = 12;
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '$wd, $mo ${d.day} ${d.year}  $h:$mm $ap';
  }

  Future<void> _initRemoteConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;

      // Dev settings: force fetch every time while testing.
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, // change to hours in production
      ));

      // In-app defaults
      await rc.setDefaults({
        'announcement_active': true,
        'announcement_title': 'Announcement',
        'announcement_text': 'Assalam Alaikum',
        'announcement_published_at': '', // empty -> no timestamp shown
      });

      final updated = await rc.fetchAndActivate();
      debugPrint('RemoteConfig fetchAndActivate -> updated=$updated');

      _readAndLogRemoteConfig(rc);
    } catch (e, st) {
      debugPrint('Remote Config init error: $e\n$st');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ));
      final updated = await rc.fetchAndActivate();
      debugPrint('RemoteConfig refresh -> updated=$updated');
      _readAndLogRemoteConfig(rc);
    } catch (e, st) {
      debugPrint('Remote Config refresh error: $e\n$st');
    }
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    // Do NOT return a Scaffold here; HomeTabs provides the outer Scaffold + AppBar.
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _active && _text.trim().isNotEmpty
            ? ListView(
          children: [
            _AnnouncementCard(
              title: _title,
              body: _text.trim(),
              when: _publishedAt, // may be null
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _refresh,
                child: const Text('Refresh message'),
              ),
            ),
          ],
        )
            : ListView(
          children: [
            const _AnnouncementCard(
              title: 'No active announcement',
              body: 'Please check back later.',
              when: null,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _refresh,
                child: const Text('Refresh message'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final String title;
  final String body;
  final DateTime? when;

  const _AnnouncementCard({
    required this.title,
    required this.body,
    required this.when,
  });

  String _format(DateTime d) {
    const w = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final wd = w[d.weekday - 1];
    final mo = m[d.month - 1];
    int h = d.hour % 12; if (h == 0) h = 12;
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    final mm = d.minute.toString().padLeft(2, '0');
    return '$wd, $mo ${d.day} ${d.year}  $h:$mm $ap';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title (bold, larger) — force black
            Text(
              title,
              style: (Theme.of(context).textTheme.titleMedium ??
                  const TextStyle(fontSize: 18))
                  .copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.black, // force black
              ),
            ),
            const SizedBox(height: 8),
            // Body — force black
            Text(
              body,
              style: (Theme.of(context).textTheme.bodyLarge ??
                  const TextStyle(fontSize: 16))
                  .copyWith(
                height: 1.35,
                color: Colors.black, // force black
              ),
            ),
            if (when != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _format(when!),
                  style: (Theme.of(context).textTheme.bodySmall ??
                      const TextStyle(fontSize: 12))
                      .copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
