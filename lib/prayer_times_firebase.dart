
// lib/prayer_times_firebase.dart
import 'dart:convert';
import 'dart:io';
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
      try { return jsonDecode(await meta.readAsString()) as Map<String, dynamic>; } catch (_) {}
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
  /// Returns false if object not found or any Firebase error—NO crash.
  Future<bool> refreshFromFirebase({int? year}) async {
    final targetYear = year ?? DateTime.now().year;
    final ref = _fs.ref('$_remoteDir/$targetYear.json');

    final local = await _localFile();
    final temp  = File('${local.path}.new');

    try {
      final task = ref.writeToFile(temp); // small JSON: simple and robust
      await task;

      if (await temp.exists()) {
        await temp.rename(local.path); // atomic swap
      } else {
        return false;
      }

      final meta = await _metaFile();
      await meta.writeAsString(
        jsonEncode({
          'year': targetYear,
          'lastUpdated': DateTime.now().toUtc().toIso8601String(),
          'source': 'firebase'
        }),
        flush: true,
      );
      return true;
    } on FirebaseException {
      return false; // object-not-found, permission-denied, etc.
    } catch (_) {
      return false;
    } finally {
      if (await temp.exists()) { try { await temp.delete(); } catch (_) {} }
    }
  }
}