
// lib/widgets/announcements_tab.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemUiOverlayStyle
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:timezone/timezone.dart' as tz;
import '../app_colors.dart'; // brand colors/gradients
import '../main.dart' show AppGradients; // read theme gradient

// NEW: generated localizations
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';

// Cool Light palette anchors
const _kLightTextPrimary = Color(0xFF0F2432); // deep blue-gray
const _kLightTextMuted   = Color(0xFF4A6273);

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

  // ------------------------ Remote Config ------------------------
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
    List<_AnnItem> parsed = _parseArray(jsonStr);

    if (parsed.isEmpty) {
      final active = rc.getBool('announcement_active');
      final title = rc.getString('announcement_title').trim();
      final text  = rc.getString('announcement_text').trim();
      final when  = rc.getString('announcement_published_at').trim();
      if (active && (title.isNotEmpty || text.isNotEmpty)) {
        parsed = <_AnnItem>[
          _AnnItem(
            id: 'legacy-0',
            title: title.isEmpty ? 'Announcement' : title, // will be localized in UI
            text: text,
            publishedAtUtc: _parseToUtc(when),
          ),
        ];
      }
    }

    parsed.sort((a, b) {
      final ta = a.publishedAtUtc?.millisecondsSinceEpoch ?? 0;
      final tb = b.publishedAtUtc?.millisecondsSinceEpoch ?? 0;
      return tb.compareTo(ta);
    });

    if (mounted) setState(() => _items = parsed);
  }

  DateTime? _parseToUtc(String raw) {
    if (raw.isEmpty) return null;
    DateTime? tryIso(String s) => DateTime.tryParse(s)?.toUtc();

    final iso = tryIso(raw);
    if (iso != null) return iso;

    final m = RegExp(r'^(\S*[T ]\d{2}:\d{2}:\d{2})([+\-]\d{2})(\d{2})$').firstMatch(raw);
    if (m != null) {
      final fixed = '${m.group(1)}${m.group(2)}:${m.group(3)}';
      final fixedDt = tryIso(fixed);
      if (fixedDt != null) return fixedDt;
    }

    final digits = RegExp(r'^\d{10,13}$');
    if (digits.hasMatch(raw)) {
      try {
        final n = int.parse(raw);
        final ms = raw.length == 13 ? n : n * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      } catch (_) {}
    }
    return null;
  }

  List<_AnnItem> _parseArray(String jsonStr) {
    if (jsonStr.isEmpty) return const [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map<_AnnItem>((e) {
          final m = (e is Map) ? Map<String, dynamic>.from(e) : <String, dynamic>{};
          final id   = (m['id'] ?? '').toString();
          final title= (m['title'] ?? '').toString();
          final text = (m['text']  ?? m['body'] ?? '').toString();
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
    final l10n = AppLocalizations.of(context)!; // <-- generated l10n
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Theme-adaptive page gradient with Light fallback if extension not present
    final gradient = Theme.of(context).extension<AppGradients>()?.page ??
        (isLight
            ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF6F9FC), Colors.white],
        )
            : AppColors.pageGradient);

    // AppBar colors per theme
    final appBarBg   = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? _kLightTextPrimary : Colors.white;
    final iconsColor = titleColor;
    final overlay    = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

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
                ? l10n.ann_default_title // <-- localized fallback
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
              title: l10n.ann_empty_title,         // <-- localized
              body:  l10n.ann_empty_body,          // <-- localized
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
          l10n.notifications_title, // <-- localized header
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
    final Color cardColor     = Colors.white;
    final Color titleColor    = isLight ? _kLightTextPrimary : Colors.black;
    final Color bodyColor     = isLight ? _kLightTextPrimary : Colors.black87;
    final Color timestampColor= isLight ? _kLightTextMuted   : Colors.black54;

    return Card(
      color: cardColor,
      elevation: 3,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.black.withOpacity(0.12),
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
