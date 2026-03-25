import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// Optional: if you want to try the string helper fallback
import 'package:url_launcher/url_launcher_string.dart';

class IalfmButton extends StatelessWidget {
  IalfmButton({super.key});

  final Uri _ialfmUrl = Uri.parse('https://www.ialfm.org');

  Future<void> _openIalfm(BuildContext context) async {
    debugPrint('[IalfmButton] Attempting to open $_ialfmUrl');

    // 1) Check if there is a handler
    final can = await canLaunchUrl(_ialfmUrl);
    if (!context.mounted) return; // <-- guard right after await

    debugPrint('[IalfmButton] canLaunchUrl = $can');
    if (!can) {
      // Emulator/devices without a browser commonly cause this
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No app found to open https://www.ialfm.org')),
      );
      return;
    }

    // 2) Try external browser (preferred)
    try {
      final launchedExternal = await launchUrl(
        _ialfmUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!context.mounted) return; // <-- guard after await
      debugPrint('[IalfmButton] launchUrl(external) returned = $launchedExternal');

      // 3) Fallback to platform default if external didn’t work
      if (!launchedExternal) {
        final launchedDefault = await launchUrl(
          _ialfmUrl,
          mode: LaunchMode.platformDefault,
        );
        if (!context.mounted) return; // <-- guard after await
        debugPrint('[IalfmButton] launchUrl(platformDefault) returned = $launchedDefault');

        if (!launchedDefault) {
          // 4) Optional: last-resort string helper (web sometimes prefers this)
          final launchedStr = await launchUrlString('https://www.ialfm.org');
          if (!context.mounted) return; // <-- guard after await
          debugPrint('[IalfmButton] launchUrlString returned = $launchedStr');

          if (!launchedStr) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not launch https://www.ialfm.org')),
            );
          }
        }
      }
    } catch (e, st) {
      debugPrint('[IalfmButton] Exception: $e\n$st');
      if (!context.mounted) return; // <-- guard after async try block
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Launch failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.open_in_new),
      label: const Text('Open IALFM'),
      onPressed: () => _openIalfm(context),
    );
  }
}