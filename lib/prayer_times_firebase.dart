
// lib/prayer_times_firebase.dart
//
// Handles local canonical JSON + yearly refresh from Firebase Storage.
// - On first run: seeds from bundled asset (assets/data/prayer_times_2026.json).
// - Thereafter: stores a local canonical file and a small meta file with the year.
// - At app start (or when FCM instructs): refreshes "prayer_times/<year>.json"
//   from Firebase Storage and atomically swaps the local canonical file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PrayerTimesRepository {
  // Remote directory in your bucket
  static const _remoteDir = 'prayer_times';

  // Local canonical file (in app documents). We keep it generic (not year-based).
  static const _localCanonicalName = 'prayer_times_local.json';

  // Local meta file (stores the year & last updated info)
  static const _metaFileName = 'prayer_times_meta.json';

  // Bundled asset used as the very first seed on first run (matches your pubspec).
  // See: pubspec.yaml -> assets/data/prayer_times_2026.json
  static const _assetSeedFileName = 'prayer_times_2026.json';

  FirebaseStorage? _storage; // lazy init

  PrayerTimesRepository({FirebaseStorage? storage}) {
    _storage = storage; // allow injection for tests
  }

  FirebaseStorage get _fs => _storage ??= FirebaseStorage.instance;

  // --- Local file paths ---

  Future<File> _localFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_localCanonicalName');
  }

  Future<File> _metaFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_metaFileName');
  }

  // --- Seed or read local canonical JSON ---

  /// Returns the canonical local JSON. If missing (first run),
  /// it loads the bundled asset `assets/data/prayer_times_2026.json`,
  /// persists it to the local canonical file, and returns the asset content.
  Future<String> loadLocalJsonOrAsset() async {
    final file = await _localFile();
    if (await file.exists()) {
      return file.readAsString();
    }
    final assetJson = await rootBundle.loadString('assets/data/$_assetSeedFileName');
    await file.writeAsString(assetJson, flush: true); // persist for next runs
    return assetJson;
  }

  /// Reads the local meta JSON (year, lastUpdated, source) if available.
  Future<Map<String, dynamic>?> readMeta() async {
    final meta = await _metaFile();
    if (await meta.exists()) {
      try {
        return jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  // --- Year awareness & refresh ---

  /// If local meta year != current year, try to refresh from Storage (graceful if missing).
  Future<bool> ensureLatestForCurrentYear() async {
    final nowYear = DateTime.now().year;
    final meta = await readMeta();
    final localYear = meta?['year'] as int?;
    if (localYear == nowYear) return true;
    return await refreshFromFirebase(year: nowYear);
  }

  /// Downloads `prayer_times/<year>.json` and atomically overwrites the local canonical file.
  /// Returns false if the object is not found or any Firebase error occurs (no crash).
  Future<bool> refreshFromFirebase({int? year}) async {
    final targetYear = year ?? DateTime.now().year;

    // Reference to your yearly JSON in the default bucket.
    // If you ever need to force a specific bucket (multiple buckets), use:
    // final fs = FirebaseStorage.instanceFor(bucket: 'gs://ialfm-prayer-times.firebasestorage.app');
    final ref = _fs.ref('$_remoteDir/$targetYear.json');

    final local = await _localFile();
    final temp = File('${local.path}.new');

    try {
      // Download to a temp file (robust for small JSON)
      final task = ref.writeToFile(temp);
      await task; // waits for completion

      if (await temp.exists()) {
        // Atomic swap
        await temp.rename(local.path);
      } else {
        return false;
      }

      // Update meta
      final meta = await _metaFile();
      await meta.writeAsString(
        jsonEncode({
          'year': targetYear,
          'lastUpdated': DateTime.now().toUtc().toIso8601String(),
          'source': 'firebase',
        }),
        flush: true,
      );

      return true;
    } on FirebaseException {
      return false; // object-not-found, permission-denied, etc.
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