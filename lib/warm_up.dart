// lib/warm_up.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:ui' as ui show TextDirection;

/// Preloads above-the-fold images and pre-shapes common text (en + ar)
/// and Material icon glyphs so the glyph atlases/pipelines are ready early.
/// Lint-safe: guards BuildContext usage across async gaps with `context.mounted`.
Future<void> warmUpAboveTheFold(BuildContext context) async {
  // --- Images: decode near actual device pixels (avoid re-decodes on first layout)
  final mq = MediaQuery.of(context);
  final dpr = mq.devicePixelRatio;
  const logicalLogoWidth = 160.0; // your header logo logical width
  final cacheWidth = (logicalLogoWidth * dpr).round();

  final images = <ImageProvider>[
    ResizeImage(
      const AssetImage('assets/branding/ialfm_logo.png'),
      width: cacheWidth,
    ),
    // Add any hero/header image visible immediately and size it similarly:
    // ResizeImage(const AssetImage('assets/images/home_hero.png'), width: (1080 * dpr).round()),
  ];

  for (final img in images) {
    await precacheImage(img, context);
    if (!context.mounted) return;
  }

  // --- Pre-shape text/glyphs: EN + AR, digits, separators used in times/dates.
  const english = <String>[
    'Prayer Times', 'Iqamah', 'Jumu’ah', 'Announcements', 'Donate',
    'Islamic Association of Lewisville - Flower Mound',
  ];
  const arabic = <String>['الصلاة', 'الإعلانات', 'الجمعة', 'تبرع', 'المسجد'];

  const westernDigits = '0123456789';
  const arabicIndicDigits = '٠١٢٣٤٥٦٧٨٩';
  const ampmEn = 'AM PM';
  const separators = ': -–/ '; // colon, space, hyphen, en-dash, slash

  final defaultStyle = DefaultTextStyle.of(context).style;
  final painter = TextPainter(textDirection: ui.TextDirection.ltr);

  for (final s in <String>[
    ...english, ...arabic, westernDigits, arabicIndicDigits, ampmEn, separators
  ]) {
    painter.text = TextSpan(text: s, style: defaultStyle);
    painter.layout(minWidth: 0, maxWidth: 2048);
  }

  // --- Warm Material Icons (the exact icons you render on first screen).
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

/// One-time offstage paint of a minimal "Salah row" to pre-prime raster caches.
/// Safe to call right after first frame; removed immediately and never shown.
Future<void> warmUpSalahRow(BuildContext context, {required bool isLight}) async {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final row = RepaintBoundary(
    child: Material(
      color: isLight ? Colors.white : const Color(0xFF0A1923),
      child: const SizedBox(
        height: 44,
        child: Row(
          children: [
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

  // Ensure a real paint pass
  await WidgetsBinding.instance.endOfFrame;

  try {
    entry.remove();
  } catch (_) {/* no-op */}
}

/// Pre-warm Intl date/time patterns for EN + AR so first-use doesn’t do work on UI thread.
Future<void> warmIntl() async {
  try {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ar');
  } catch (_) {
    // Often already provided by flutter_localizations; safe to ignore.
  }
  final now = DateTime.now();
  for (final locale in const ['en', 'ar']) {
    DateFormat.Hm(locale).format(now);
    DateFormat.jm(locale).format(now);
    DateFormat.EEEE(locale).format(now);
  }
}

// If you ship SVGs above-the-fold, you can add a helper like this:
//
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:flutter/services.dart' show rootBundle;
//
// Future<void> precacheSvg(String assetPath) async {
//   final svgStr = await rootBundle.loadString(assetPath);
//   final loader = SvgStringLoader(svgStr);
//   await svg.cache.putIfAbsent(loader.cacheKey(null), () => loader.loadBytes(null));
// }