
// lib/widgets/announcements_tab.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:timezone/timezone.dart' as tz;

/// Lightweight UI model for each announcement item.
class _AnnItem {
  final String id;
  final String title;
  final String text;
  /// Canonical UTC timestamp (nullable if the server omits it).
  final DateTime? publishedAtUtc;

  _AnnItem({
    required this.id,
    required this.title,
    required this.text,
    required this.publishedAtUtc,
  });
}

class AnnouncementsTab extends StatefulWidget {
  final tz.Location location; // passed from HomeTabs (America/Chicago)
  const AnnouncementsTab({super.key, required this.location});

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab>
    with WidgetsBindingObserver {
  bool _loading = true;
  List<_AnnItem> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRemoteConfig(); // RC is the only source
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Auto-refresh when app returns to foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  // ---------------------- Remote Config ----------------------

  /// Initialize RC and load announcements immediately.
  Future<void> _initRemoteConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;

      // NOTE: RemoteConfigSettings is NOT const — do not prefix with `const`.
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, // update whenever asked
      ));

      // Legacy single-item keys for backward compatibility.
      await rc.setDefaults(const {
        'announcement_active': true,
        'announcement_title': 'Announcement',
        'announcement_text': 'Assalamu Alaikum', // spelling tweak (optional)
        'announcement_published_at': '',
        // New shape: array JSON and optional version
        'announcements_json': '[]',
        'announcements_version': '',
      });

      final updated = await rc.fetchAndActivate();
      debugPrint('RemoteConfig fetchAndActivate -> updated=$updated');

      _readAnnouncements(rc);
    } catch (e, st) {
      debugPrint('Remote Config init error: $e\n$st');
      if (mounted) {
        setState(() {
          _items = const [];
          _loading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Manual refresh for pull-to-refresh and lifecycle resume.
  Future<void> _refresh() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ));
      final updated = await rc.fetchAndActivate();
      debugPrint('RemoteConfig refresh -> updated=$updated');
      _readAnnouncements(rc);
    } catch (e, st) {
      debugPrint('Remote Config refresh error: $e\n$st');
    }
  }

  /// Parse announcements from RC, supporting both array JSON and legacy single keys.
  void _readAnnouncements(FirebaseRemoteConfig rc) {
    // Preferred: array field
    final jsonStr = rc.getString('announcements_json').trim();
    List<_AnnItem> parsed = _parseArray(jsonStr);

    // Fallback: legacy single item
    if (parsed.isEmpty) {
      final active = rc.getBool('announcement_active');
      final title = rc.getString('announcement_title').trim();
      final text = rc.getString('announcement_text').trim();
      final when = rc.getString('announcement_published_at').trim();
      if (active && (title.isNotEmpty || text.isNotEmpty)) {
        parsed = <_AnnItem>[
          _AnnItem(
            id: 'legacy-0',
            title: title.isEmpty ? 'Announcement' : title,
            text: text,
            publishedAtUtc: _parseToUtc(when),
          ),
        ];
      }
    }

    // Sort newest first
    parsed.sort((a, b) {
      final ta = a.publishedAtUtc?.millisecondsSinceEpoch ?? 0;
      final tb = b.publishedAtUtc?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });

    if (mounted) {
      setState(() => _items = parsed);
    }
  }

  // ---------------------- Parsing helpers ----------------------

  /// Accepts ISO-8601 with or without colon in TZ offset, or epoch sec/ms.
  DateTime? _parseToUtc(String raw) {
    if (raw.isEmpty) return null;

    DateTime? tryIso(String s) {
      final dt = DateTime.tryParse(s);
      return dt?.toUtc();
    }

    // 1) ISO as-is
    final iso = tryIso(raw);
    if (iso != null) return iso;

    // 2) Fix offsets like "-0600" -> "-06:00"
    final m = RegExp(r'^(.*[T ]\d{2}:\d{2}:\d{2})([+\-]\d{2})(\d{2})$')
        .firstMatch(raw);
    if (m != null) {
      final fixed = '${m.group(1)}${m.group(2)}:${m.group(3)}';
      final fixedDt = tryIso(fixed);
      if (fixedDt != null) return fixedDt;
    }

    // 3) Epoch seconds or milliseconds
    final digits = RegExp(r'^\d{10,13}$');
    if (digits.hasMatch(raw)) {
      try {
        final n = int.parse(raw);
        final ms = raw.length == 13 ? n : n * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      } catch (_) {}
    }
    return null;
    // If null, the UI will simply omit the timestamp line.
  }

  /// Parses announcements_json array.
  List<_AnnItem> _parseArray(String jsonStr) {
    if (jsonStr.isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map<_AnnItem>((e) {
          // Remove unnecessary cast warning by dropping `as Map`
          final m = (e is Map)
              ? Map<String, dynamic>.from(e)
              : <String, dynamic>{};

          // Normalize keys commonly used upstream.
          final id = (m['id'] ?? '').toString();
          final title = (m['title'] ?? '').toString();
          final text = (m['text'] ?? m['body'] ?? '').toString();
          final when = (m['published_at'] ?? m['publishedAt'] ?? m['published'])
              ?.toString() ?? '';

          return _AnnItem(
            id: id.isEmpty ? 'item-${DateTime.now().microsecondsSinceEpoch}' : id,
            title: title,
            text: text,
            publishedAtUtc: _parseToUtc(when),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('announcements_json parse error: $e');
    }
    return const [];
  }

  // ---------------------- Formatting helpers ----------------------

  String _formatCentral(DateTime dUtc) {
    final central = tz.TZDateTime.from(dUtc, widget.location);
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final wd = w[central.weekday - 1];
    final mo = m[central.month - 1];
    int h = central.hour % 12; if (h == 0) h = 12;
    final ap = central.hour >= 12 ? 'PM' : 'AM';
    final mm = central.minute.toString().padLeft(2, '0');
    return '$wd, $mo ${central.day} ${central.year} $h:$mm $ap';
  }

  // ---------------------- UI ----------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasAny = _items.any((it) =>
    it.title.trim().isNotEmpty || it.text.trim().isNotEmpty);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: hasAny
          ? ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final a = _items[index];
          final whenLabel =
          (a.publishedAtUtc != null) ? _formatCentral(a.publishedAtUtc!) : null;
          return _AnnouncementCard(
            title: (a.title.isEmpty && a.text.isNotEmpty)
                ? 'Announcement'
                : a.title,
            body: a.text,
            whenLabel: whenLabel,
          );
        },
      )
          : ListView(
        children: const [
          _AnnouncementCard(
            title: 'No active announcement',
            body: 'Please check back later.',
            whenLabel: null,
          ),
        ],
      ),
    );

    // Swipe-to-refresh: RC fetch only (no local asset).
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: content,
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final String title;
  final String body;
  final String? whenLabel;
  const _AnnouncementCard({
    required this.title,
    required this.body,
    required this.whenLabel,
  });

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
            // Title
            Text(
              title.isEmpty ? 'Announcement' : title,
              style: (Theme.of(context).textTheme.titleMedium ??
                  const TextStyle(fontSize: 18))
                  .copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            // Body
            Text(
              body,
              style: (Theme.of(context).textTheme.bodyLarge ??
                  const TextStyle(fontSize: 16))
                  .copyWith(
                height: 1.35,
                color: Colors.black,
              ),
            ),
            if (whenLabel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  whenLabel!,
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