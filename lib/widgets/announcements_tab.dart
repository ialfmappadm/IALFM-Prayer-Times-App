// lib/widgets/announcements_tab.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemUiOverlayStyle
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app_colors.dart'; // brand colors/gradients
import '../main.dart' show AppGradients; // read theme gradient
// Generated localizations
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';

// Light palette anchors
const _kLightTextPrimary = Color(0xFF0F2432); // deep blue‑gray
const _kLightTextMuted = Color(0xFF4A6273);

/// Lightweight UI model for each announcement item.
class _AnnItem {
  final String id;
  final String title;
  final String text;
  final DateTime? publishedAtUtc; // canonical UTC timestamp
  const _AnnItem({
    required this.id,
    required this.title,
    required this.text,
    required this.publishedAtUtc,
  });
}

class AnnouncementsTab extends StatefulWidget {
  final tz.Location location;
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
    _initRemoteConfig();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  // ------------------- Remote Config -------------------
  Future<void> _initRemoteConfig() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero,
      ));
      await rc.setDefaults(const {
        'announcement_active': true,
        'announcement_title': 'Announcement',
        'announcement_text': 'Assalamu Alaikum',
        'announcement_published_at': '',
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
      if (mounted) setState(() => _loading = false);
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
      _readAnnouncements(rc);
    } catch (e, st) {
      debugPrint('Remote Config refresh error: $e\n$st');
    }
  }

  void _readAnnouncements(FirebaseRemoteConfig rc) {
    final jsonStr = rc.getString('announcements_json').trim();
    // Parse list (may be empty)
    final list = _parseArray(jsonStr);

    // Parse legacy single (may be active or empty)
    final active = rc.getBool('announcement_active');
    final title = rc.getString('announcement_title').trim();
    final text = rc.getString('announcement_text').trim();
    final when = rc.getString('announcement_published_at').trim();

    final List<_AnnItem> merged = [...list];

    if (active && (title.isNotEmpty || text.isNotEmpty)) {
      final legacy = _AnnItem(
        id: 'legacy-0',
        title: title.isEmpty ? 'Announcement' : title,
        text: text,
        publishedAtUtc: _parseToUtc(when),
      );
      // If list already contains an item with this id, replace it; else append.
      final ix = merged.indexWhere((e) => e.id == legacy.id);
      if (ix >= 0) {
        merged[ix] = legacy;
      } else {
        merged.add(legacy);
      }
    }

    // Sort newest first by publishedAtUtc (nulls last)
    merged.sort((a, b) {
      final ta = a.publishedAtUtc?.millisecondsSinceEpoch ?? -1;
      final tb = b.publishedAtUtc?.millisecondsSinceEpoch ?? -1;
      return tb.compareTo(ta);
    });

    if (mounted) setState(() => _items = merged);
  }

  /// Robustly parse many forms:
  /// - 2026-02-03T17:48:00-0600
  /// - 2026-02-03T17:48:00-06:00
  /// - 2026-02-03 17:48-0600
  /// - 2026-02-03T17:48-0600   (adds :00 seconds)
  /// Returns UTC, or null on failure.
  DateTime? _parseToUtc(String raw) {
    if (raw.isEmpty) return null;

    String s = raw.trim();

    // Normalize date-time separator (space -> 'T')
    s = s.replaceAllMapped(
      RegExp(r'^(\d{4}-\d{2}-\d{2})\s+'),
          (m) => '${m.group(1)}T',
    );

    // If time lacks seconds (HH:mm), add :00 just before the offset or end
    final rxNoSeconds = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?!:)');
    if (rxNoSeconds.hasMatch(s)) {
      s = s.replaceAllMapped(
        RegExp(r'(T\d{2}:\d{2})(?=([Zz]|[+\-]\d{2}:?\d{2})?$)'),
            (m) => '${m.group(1)}:00',
      );
    }

    // Normalize timezone offsets like -0600 -> -06:00 (at end of string)
    s = s.replaceAllMapped(
      RegExp(r'([+\-]\d{2})(\d{2})$'),
          (m) => '${m.group(1)}:${m.group(2)}',
    );

    // Try strict ISO parse
    try {
      final dt = DateTime.parse(s);
      return dt.toUtc();
    } catch (_) {}

    // Final fallback: force seconds and colonized offset again
    try {
      String t = s;
      t = t.replaceAllMapped(
        RegExp(r'(\d{2}:\d{2})(?=([Zz]|[+\-]\d{2}:\d{2})?$)'),
            (m) => '${m.group(1)}:00',
      );
      return DateTime.parse(t).toUtc();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('published_at parse failed: "$raw" -> "$s"\n$e\n$st');
      }
      return null;
    }
  }

  List<_AnnItem> _parseArray(String jsonStr) {
    if (jsonStr.isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map<_AnnItem>((e) {
          final m = (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{};
          final id = (m['id'] ?? '').toString();
          final title = (m['title'] ?? '').toString();
          final text = (m['text'] ?? m['body'] ?? '').toString();
          final when = (m['published_at'] ?? m['publishedAt'] ?? m['published'])?.toString() ?? '';
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

  String _formatCentral(DateTime dUtc) {
    final central = tz.TZDateTime.from(dUtc, widget.location);
    const w = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final wd = w[central.weekday - 1];
    final mo = m[central.month - 1];
    int h = central.hour % 12; if (h == 0) h = 12;
    final ap = central.hour >= 12 ? 'PM' : 'AM';
    final mm = central.minute.toString().padLeft(2, '0');
    return '$wd, $mo ${central.day} ${central.year} $h:$mm $ap';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Theme‑adaptive page gradient with Light fallback if extension not present
    final gradient = Theme.of(context).extension<AppGradients>()?.page ??
        (isLight
            ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF6F9FC), Colors.white],
        )
            : AppColors.pageGradient);

    // AppBar colors per theme
    final appBarBg = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? _kLightTextPrimary : Colors.white;
    final iconsColor = titleColor;
    final overlay = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    Widget listContent;
    if (_loading) {
      listContent = const Center(child: CircularProgressIndicator());
    } else {
      final hasAny = _items.any((it) => it.title.trim().isNotEmpty || it.text.trim().isNotEmpty);
      final content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: hasAny
            ? ListView.separated(
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final a = _items[index];
            final whenLabel = (a.publishedAtUtc != null) ? _formatCentral(a.publishedAtUtc!) : null;
            final safeTitle = (a.title.isEmpty && a.text.isNotEmpty)
                ? l10n.ann_default_title
                : a.title;
            return _AnnouncementCard(
              title: safeTitle,
              body: a.text,
              whenLabel: whenLabel,
            );
          },
        )
            : ListView(
          children: [
            _AnnouncementCard(
              title: l10n.ann_empty_title,
              body: l10n.ann_empty_body,
              whenLabel: null,
            ),
          ],
        ),
      );
      listContent = RefreshIndicator(onRefresh: _refresh, child: content);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.notifications_title,
          style: TextStyle(
            color: titleColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: iconsColor),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(child: listContent),
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
    final isLight = Theme.of(context).brightness == Brightness.light;
    // White bubble in both themes; dark text in Dark mode for readability
    final Color cardColor = Colors.white;
    final Color titleColor = isLight ? _kLightTextPrimary : Colors.black;
    final Color bodyColor = isLight ? _kLightTextPrimary : Colors.black87;
    final Color timestampColor= isLight ? _kLightTextMuted : Colors.black54;
    return Card(
      color: cardColor,
      elevation: 3,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              style: (Theme.of(context).textTheme.titleMedium ??
                  const TextStyle(fontSize: 18))
                  .copyWith(
                fontWeight: FontWeight.w800,
                color: titleColor,
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
                color: bodyColor,
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
                      .copyWith(color: timestampColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}