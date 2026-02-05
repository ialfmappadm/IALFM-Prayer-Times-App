// lib/prayer_times_firebase.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PrayerTimesRepository {
  static const _remoteDir = 'prayer_times';
  static const _localFileName = 'prayer_times_local.json';
  static const _metaFileName  = 'prayer_times_meta.json';

  FirebaseStorage? _storage; // LAZY: prevents touching Firebase in constructor
  PrayerTimesRepository({FirebaseStorage? storage}) {
    _storage = storage; // allow injection for tests if needed
  }
  FirebaseStorage get _fs => _storage ??= FirebaseStorage.instance;

  Future<File> _localFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_localFileName');
  }

  Future<File> _metaFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_metaFileName');
  }

  /// Returns the canonical local JSON; if missing on first run,
  /// copies bundled asset `assets/data/prayer_times_local.json`.
  Future<String> loadLocalJsonOrAsset() async {
    final file = await _localFile();
    if (await file.exists()) return file.readAsString();
    final assetJson = await rootBundle.loadString('assets/data/$_localFileName');
    await file.writeAsString(assetJson, flush: true); // persist for next runs
    return assetJson;
  }

  Future<Map<String, dynamic>?> readMeta() async {
    final meta = await _metaFile();
    if (await meta.exists()) {
      try {
        return jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  /// If local meta year != current, try to refresh from Storage (graceful if missing).
  Future<bool> ensureLatestForCurrentYear() async {
    final nowYear = DateTime.now().year;
    final meta = await readMeta();
    final localYear = meta?['year'] as int?;
    if (localYear == nowYear) return true;
    return await refreshFromFirebase(year: nowYear);
  }

  /// Downloads `prayer_times/<year>.json` and atomically overwrites the local file.
  /// Returns true if local file was updated; false on any Firebase/network error (fallback to local).
  Future<bool> refreshFromFirebase({int? year}) async {
    final targetYear = year ?? DateTime.now().year;

    // IMPORTANT: Build the ref with child(...) to avoid subtle leading-slash path issues.
    final ref = _fs.ref().child(_remoteDir).child('$targetYear.json');
    final local = await _localFile();
    final temp  = File('${local.path}.new');

    try {
      // Quick existence check (avoids noisy 404 path confusion; does not fetch contents).
      // If your object is present, this call succeeds quickly; otherwise we bail out quietly.
      await ref.getMetadata();

      // Small JSON: download in memory (2 MB cap)
      final Uint8List? data = await ref.getData(2 * 1024 * 1024);
      if (data == null) return false;

      // Atomic write (temp -> rename)
      await temp.writeAsBytes(data, flush: true);
      await temp.rename(local.path);

      // Meta with timestamp (used by UI to show a discreet "updated" hint once)
      final meta = await _metaFile();
      await meta.writeAsString(
        jsonEncode({
          'year': targetYear,
          'lastUpdated': DateTime.now().toUtc().toIso8601String(),
          'source': 'firebase',
        }),
        flush: true,
      );

      // Helpful log (path validation)
      // You should see this path in your Firebase Storage console.
      // Example: prayer_times/2026.json
      // If your file uses a different directory, adjust _remoteDir accordingly.
      // (This avoids false 404s when a blob exists at another path.)
      // ignore: avoid_print
      print('[PrayerTimes] Updated from Storage: $_remoteDir/$targetYear.json');

      return true;
    } on FirebaseException catch (e) {
      // Common cases: object-not-found (404), permission-denied/appcheck (403), etc.
      // We fall back to local JSON without crashing.
      // ignore: avoid_print
      print('[PrayerTimes] Storage fetch failed (${e.code}). Path: $_remoteDir/$targetYear.json');
      return false;
    } catch (_) {
      return false;
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }
}