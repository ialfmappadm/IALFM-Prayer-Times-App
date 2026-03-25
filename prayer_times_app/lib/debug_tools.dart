// lib/debug_tools.dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Toggle to hide/show the crash test UI without touching main.dart.
/// This is respected only in debug builds (kDebugMode).
const bool kEnableCrashTestButton = true;

/// Initialize Analytics and log a simple event so the analyzer
/// doesn't complain about an unused local variable in main.dart.
/// You may call this once during startup.
Future<FirebaseAnalytics> initAnalyticsAndLogAppOpen() async {
  final analytics = FirebaseAnalytics.instance;
  await analytics.logAppOpen();
  return analytics;
}

/// A compact debug-only panel that exposes:
///  • Crash (fatal)    → FirebaseCrashlytics.instance.crash()
///  • Non‑fatal        → recordError(..., fatal:false)
///
/// Hidden in release builds and when kEnableCrashTestButton == false.
class CrashTestPanel extends StatelessWidget {
  final EdgeInsets padding;
  final Axis direction;
  final bool elevatedCard;

  const CrashTestPanel({
    super.key,
    this.padding = const EdgeInsets.all(12),
    this.direction = Axis.horizontal,
    this.elevatedCard = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || !kEnableCrashTestButton) {
      return const SizedBox.shrink();
    }

    final content = Wrap(
      spacing: 8,
      runSpacing: 8,
      direction: direction,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.error_outline),
          label: const Text('Crash (fatal)'),
          onPressed: () => FirebaseCrashlytics.instance.crash(),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.bug_report_outlined),
          label: const Text('Non‑fatal'),
          onPressed: () async {
            try {
              throw StateError('Synthetic non‑fatal for QA');
            } catch (e, st) {
              await FirebaseCrashlytics.instance.recordError(
                e,
                st,
                fatal: false,
                reason: 'QA non‑fatal test',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Non‑fatal recorded')),
                );
              }
            }
          },
        ),
      ],
    );

    if (!elevatedCard) return Padding(padding: padding, child: content);

    return Padding(
      padding: padding,
      child: Card(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: content,
        ),
      ),
    );
  }
}