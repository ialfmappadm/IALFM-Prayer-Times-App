// lib/widgets/iqamah_change_sheet.dart
import 'package:flutter/material.dart';
import '../services/iqamah_change_service.dart';

Future<void> showIqamahChangeSheet(BuildContext context, IqamahChange ch) async {
  const gold = Color(0xFFC7A447);
  final cs = Theme.of(context).colorScheme;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: false,
    backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final titleStyle = Theme.of(ctx).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      );
      final subStyle = Theme.of(ctx).textTheme.bodyMedium?.copyWith(
        color: cs.onSurface.withValues(alpha: 0.85),
      );
      final labelStyle = Theme.of(ctx).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      );
      final timeStyle = Theme.of(ctx).textTheme.titleMedium?.copyWith(
        color: cs.onSurface,
      );

      // Bigger, bolder for the single‑Salah time row
      final bigTimeStyle = Theme.of(ctx).textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      );

      // Larger Salah name in single‑Salah layout
      final bigLabelStyle = Theme.of(ctx).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 28, // impact
        color: cs.onSurface,
      );

      Widget multiSalah() {
        return Column(
          children: [
            for (final line in ch.uiLines12)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(line.label, style: labelStyle)),
                    Text('${line.old12}  →  ${line.new12}', style: timeStyle),
                  ],
                ),
              ),
          ],
        );
      }

      /// CENTERED single‑Salah block
      Widget singleSalah() {
        final name = ch.singleSalahName ?? '';
        final oldT = ch.singleOld12 ?? '';
        final newT = ch.singleNew12 ?? '';

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center, // center the column
          children: [
            // Centered Salah name
            Text(
              name,
              style: bigLabelStyle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // Center the big time row as well
            Align(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  '$oldT  →  $newT',
                  style: bigTimeStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Centered heading (no bell icon)
              Center(child: Text(ch.heading, style: titleStyle)),         // “Iqamah Time Change”
              const SizedBox(height: 6),
              Center(child: Text(ch.startingPhrase, style: subStyle)),    // “Starting this Monday, March 8, 2026”
              const SizedBox(height: 12),

              // Visual divider under header
              Divider(
                height: 1,
                thickness: 1,
                color: cs.onSurface.withValues(alpha: 0.10),
              ),
              const SizedBox(height: 12),

              // Single vs multi (no bullets)
              if (ch.isSingleChange) singleSalah() else multiSalah(),
              const SizedBox(height: 20),

              // CTA
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('OK, got it'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}