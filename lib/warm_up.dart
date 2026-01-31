// lib/warm_up.dart
import 'package:flutter/material.dart';

/// Preloads above-the-fold images and pre-shapes common text (en + ar)
/// and Material icon glyphs so the glyph atlases/pipelines are ready early.
/// Lint-safe: guards BuildContext usage across async gaps with `context.mounted`.
Future<void> warmUpAboveTheFold(BuildContext context) async {
  // 1) Pre-cache first-screen images (decode close to on-screen size).
  //    Use ResizeImage to avoid decoding full-resolution unnecessarily.
  final images = <ImageProvider>[
    const ResizeImage(
      AssetImage('assets/branding/ialfm_logo.png'),
      width: 160, // header logo visual width
    ),
    // Add any hero/header image that is visible immediately:
    // const ResizeImage(AssetImage('assets/images/home_hero.png'), width: 1080),
  ];

  for (final img in images) {
    await precacheImage(img, context);       // uses `context` immediately
    if (!context.mounted) return;            // guard same context after await
  }

  // 2) Pre-shape common strings to build text glyph atlases up-front.
  //    Kept synchronous; no awaits between context reads and layout.
  const english = <String>[
    'Prayer Times', 'Iqamah', 'Jumu’ah', 'Announcements', 'Donate',
    'Islamic Association of Lewisville - Flower Mound',
  ];
  const arabic = <String>['الصلاة', 'الإعلانات', 'الجمعة', 'تبرع', 'المسجد'];

  // Digits & date-time (helps with time rows and headers)
  const digits = '0123456789';
  const ampm = 'AM PM';

  final defaultStyle = DefaultTextStyle.of(context).style;
  final painter = TextPainter(textDirection: TextDirection.ltr);

  for (final s in <String>[...english, ...arabic, digits, ampm]) {
    painter.text = TextSpan(text: s, style: defaultStyle);
    painter.layout(minWidth: 0, maxWidth: 2048);
  }

  // 3) Warm Material Icons (the exact icons you render on first screen).
  final iconStyle = defaultStyle.copyWith(
    fontFamily: Icons.volunteer_activism.fontFamily,
    fontSize: 22, // roughly your visual size; value not critical
  );
  final iconCodePoints = <int>[
    Icons.volunteer_activism.codePoint, // donate
    Icons.schedule.codePoint,
    Icons.campaign.codePoint,
    Icons.tag.codePoint,
    Icons.contact_page.codePoint,
    Icons.more_horiz.codePoint,
  ];
  for (final cp in iconCodePoints) {
    painter.text = TextSpan(text: String.fromCharCode(cp), style: iconStyle);
    painter.layout(minWidth: 0, maxWidth: 200);
  }
}

/// One-time offstage paint of a minimal "Salah row" to pre-prime shaders/pipelines.
/// Safe to call right after first frame; removed immediately and never shown.
/// Lint-safe: no null-check on `Overlay.of(context)` (non-null in this SDK),
/// and no context use after the await beyond removal of the entry.
Future<void> warmUpSalahRow(BuildContext context, {required bool isLight}) async {
  final overlay = Overlay.of(context); // non-null in your Flutter SDK

  final row = RepaintBoundary(
    child: Material(
      color: isLight ? Colors.white : const Color(0xFF0A1923),
      child: SizedBox(
        height: 44,
        child: Row(
          children: const [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Fajr', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            Expanded(
              child: Center(
                child: Text('05:56', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('06:15', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  final entry = OverlayEntry(builder: (_) => Offstage(child: row));
  overlay.insert(entry);

  // Let it render exactly once, then remove. Use microtask (no frame delay required).
  await Future<void>.microtask(() {});

  // Remove the entry (safe even if overlay is disposing; ignore if already removed).
  try {
    entry.remove();
  } catch (_) {
    // no-op
  }
}