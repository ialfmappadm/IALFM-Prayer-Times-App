import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:file_saver/file_saver.dart';

/// Centralized, flag-driven save service so the page stays lean.
class SaveService {
  // ===== Download behavior flags =====
  static const bool kSaveToGallery = true;                // iOS/Android: Photos/Gallery
  static const bool kAndroidAlsoSaveToDownloads = false;  // Android only: add Downloads (SAF) save
  static const bool kKeepInternalSandboxCopy = false;     // handled by caller if needed

  /// Save PNG bytes to Photos/Gallery; also Downloads on Android if the flag is set.
  /// Shows a brief SnackBar with the current Photos permission states when [probe] is true.
  static Future<void> saveToGalleryOrDownloads({
    required BuildContext context,
    required Uint8List bytes,
    required String fname,
    bool probe = false,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!kSaveToGallery) return; // feature disabled

    if (Platform.isIOS) {
      // Check & request iOS Photos permissions: accept AddOnly OR Full (granted/limited).
      var addOnly = await Permission.photosAddOnly.status;
      var photos  = await Permission.photos.status;

      if (probe) {
        messenger.showSnackBar(
          SnackBar(content: Text('Photos status → addOnly: ${addOnly.name}, full: ${photos.name}')),
        );
      }

      bool hasWrite = addOnly.isGranted || photos.isGranted || photos.isLimited;
      if (!hasWrite) {
        addOnly = await Permission.photosAddOnly.request();
        hasWrite = addOnly.isGranted;
      }
      if (!hasWrite) {
        photos = await Permission.photos.request();
        hasWrite = photos.isGranted || photos.isLimited;
      }
      if (!hasWrite) {
        throw 'Photos permission denied (addOnly: ${addOnly.name}, full: ${photos.name})';
      }

      final res = await ImageGallerySaverPlus.saveImage(bytes, name: fname, quality: 100);
      assert(() { debugPrint('Gallery save result (iOS): $res'); return true; }());
      messenger.showSnackBar(const SnackBar(content: Text('Saved to Photos')));
      return;
    }

    // ANDROID
    final res = await ImageGallerySaverPlus.saveImage(bytes, name: fname, quality: 100);
    assert(() { debugPrint('Gallery save result (Android): $res'); return true; }());
    if (kAndroidAlsoSaveToDownloads) {
      await FileSaver.instance.saveFile(
        name: fname,
        bytes: bytes,
        fileExtension: 'png',
        mimeType: MimeType.png,
      );
    }
    messenger.showSnackBar(const SnackBar(content: Text('Saved to Photos/Gallery')));
  }
}
