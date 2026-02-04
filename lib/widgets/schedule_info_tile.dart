// lib/widgets/schedule_info_tile.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_storage/firebase_storage.dart';

import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';
import '../prayer_times_firebase.dart';
//import '../ux_prefs.dart';

class ScheduleInfoTile extends StatefulWidget {
  const ScheduleInfoTile({super.key});

  @override
  State<ScheduleInfoTile> createState() => _ScheduleInfoTileState();
}

class _ScheduleInfoTileState extends State<ScheduleInfoTile> {
  final _repo = PrayerTimesRepository();

  static const _gold = Color(0xFFC7A447);

  /// The UTC instant we consider “last updated”.
  DateTime? _lastUtc;
  /// Whether `_lastUtc` came from cloud metadata (true) or local file mtime (false).
  bool _fromCloud = false;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadStamps(); // loads _lastUtc & _fromCloud, then setState
  }

  /// Reformat on locale changes without re-reading files (so switching EN/AR doesn’t “wipe” the line).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lastUtc != null) {
      setState(() {}); // triggers rebuild to re-run DateFormat with new locale
    }
  }

  // ───────────────────────── Load stamps (cloud or local) ─────────────────────────
  Future<void> _loadStamps() async {
    // 1) Prefer cloud meta (written by repo on successful download)
    final meta = await _repo.readMeta();
    final stamp = (meta?['lastUpdated'] as String?)?.trim();
    if (stamp != null && stamp.isNotEmpty) {
      _lastUtc = DateTime.tryParse(stamp)?.toUtc();
      _fromCloud = true;
    }

    // 2) Else use local data file mtime
    if (_lastUtc == null) {
      final local = await _readLocalFileMTime();
      if (local != null) {
        _lastUtc = local.toUtc();
        _fromCloud = false;
      }
    }

    // 3) As a last resort, use “now” (should be rare) so we still show a time.
    _lastUtc ??= DateTime.now().toUtc();
    _fromCloud = _fromCloud && _lastUtc != null;

    if (mounted) setState(() {});
  }

  Future<DateTime?> _readLocalFileMTime() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/prayer_times_local.json');
      if (await f.exists()) {
        final st = await f.stat();
        return st.modified; // local time
      }
    } catch (_) {}
    return null;
  }

  // ───────────────────────── Formatting helpers ─────────────────────────
  String _fmtCentral(DateTime utc, {required String suffix, required BuildContext context}) {
    // Convert UTC -> America/Chicago (fallback to device local if tz DB not ready)
    DateTime central;
    try {
      final loc = tz.getLocation('America/Chicago');
      central = tz.TZDateTime.from(utc, loc);
    } catch (_) {
      central = utc.toLocal();
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat('EEE, MMM d • h:mm a', locale);
    return '${fmt.format(central)} $suffix';
  }

  String _label(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ts = _fmtCentral(_lastUtc!, suffix: l10n.about_ct_suffix, context: context);
    if (_fromCloud) return ts;
    return '${l10n.about_last_updated_local_prefix} $ts';
  }

  // ───────────────────────── Hidden manual refresh ─────────────────────────
  Future<void> _manualRefresh() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);

    try {
      // Known current stamp before we peek cloud
      DateTime currentKnownUtc = _lastUtc ?? DateTime.now().toUtc();

      // Peek cloud metadata (no content download)
      final year = DateTime.now().year;
      final ref = FirebaseStorage.instance.ref('prayer_times/$year.json');
      FullMetadata? md;
      try {
        md = await ref.getMetadata();
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') {
          // No cloud file → “No update required”
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.about_refresh_none_toast)),
          );
          // Keep displaying the current stamp (don’t change)
          setState(() {});
          return;
        }
      }

      final remoteUtc = (md?.updated ?? md?.timeCreated)?.toUtc();
      final isNewer = remoteUtc != null && remoteUtc.isAfter(currentKnownUtc);

      if (!isNewer) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.about_refresh_none_toast)),
        );
        setState(() {}); // keep the same displayed stamp
        return;
      }

      // Newer exists → download & persist
      final updated = await _repo.refreshFromFirebase(year: year);
      if (!mounted) return;

      if (updated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.about_refresh_updated_toast)),
        );
        // Reload stamps; since a cloud meta is now written, we will show cloud stamp
        await _loadStamps();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.about_refresh_failed_toast('network/unavailable'))),
        );
        // Keep previous stamp visible
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.about_refresh_failed_toast('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    // If still loading stamps, render an inline progress (brief).
    final loaded = _lastUtc != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gold heading
        Text(
          l10n.about_last_updated_title,
          style: const TextStyle(
            color: _gold,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),

        GestureDetector(
          onLongPress: _manualRefresh, // hidden action
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: loaded
                    ? Text(
                  _label(context),
                  maxLines: 2,
                  style: TextStyle(
                    color: cs.onSurface,          // regular text color
                    fontSize: 15,
                    fontWeight: FontWeight.w600,  // keep slightly bold
                  ),
                )
                    : Text(
                  '…',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const SizedBox(width: 18, height: 18),
            ],
          ),
        ),
      ],
    );
  }
}