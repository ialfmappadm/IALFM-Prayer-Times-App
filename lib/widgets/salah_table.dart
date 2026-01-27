
// lib/widgets/salah_table.dart
import 'package:flutter/material.dart';
import 'prayer_glyphs.dart';
import '../utils/time_utils.dart';
import '../app_colors.dart';
import '../localization/prayer_labels.dart';

class SalahTable extends StatelessWidget {
  final Map<String, String> adhanByName;
  final Map<String, String>? iqamahByName;
  final List<String> order;
  final String? highlightName;

  // Text styles
  final TextStyle? headerStyle;
  final TextStyle? nameStyle;
  final TextStyle? adhanStyle;
  final TextStyle? iqamahStyle;

  // Row colors
  final Color rowEvenColor;
  final Color rowOddColor;

  /// Highlight for **Dark** (and fallback)
  final Color highlightColor;

  /// Highlight for **Light**
  final Color? highlightColorLight;

  // Layout
  final bool expandRowsToFill;

  // Header visuals
  final bool headerGreen;
  final Gradient? headerBackgroundGradient;
  final Color? headerBackgroundColor;

  /// Light-mode hairline divider between rows
  final Color? rowDividerColorLight;
  final double rowDividerThickness;

  const SalahTable({
    super.key,
    required this.adhanByName,
    this.iqamahByName,
    this.order = const ['Fajr','Sunrise','Dhuhr','Asr','Maghrib','Isha',"Jummua'h"],
    this.highlightName,
    this.headerStyle,
    this.nameStyle,
    this.adhanStyle,
    this.iqamahStyle,
    this.rowEvenColor = AppColors.bgSecondary,
    this.rowOddColor = AppColors.bgSecondary,
    this.highlightColor = AppColors.rowHighlight,
    this.highlightColorLight,
    this.expandRowsToFill = false,
    this.headerGreen = false,
    this.headerBackgroundGradient,
    this.headerBackgroundColor,
    this.rowDividerColorLight,
    this.rowDividerThickness = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Fallback text styles
    final headerTextStyle = headerStyle ?? const TextStyle(
      color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600,
    );
    final nameTextStyle = nameStyle ?? const TextStyle(
      color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500,
    );
    final adhanTextStyle = adhanStyle ?? const TextStyle(
      color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
    );
    final iqamahTextStyle = iqamahStyle ?? const TextStyle(
      color: AppColors.textMuted, fontSize: 16, fontWeight: FontWeight.w500,
    );

    // Keep only entries that have an adhan time
    final entries = order.where((n) {
      final v = adhanByName[n];
      return v != null && v.isNotEmpty;
    }).toList();

    // Header background
    final BoxDecoration? headerDecoration = headerGreen
        ? const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ),
    )
        : (headerBackgroundGradient != null
        ? BoxDecoration(gradient: headerBackgroundGradient)
        : (headerBackgroundColor != null
        ? BoxDecoration(color: headerBackgroundColor)
        : const BoxDecoration(gradient: AppColors.headerGradient)));

    Widget buildRow(String name, int i) {
      final adhanRaw  = adhanByName[name]!;
      final adhan12   = format12h(adhanRaw);  // 12h English AM/PM
      final iqamahRaw = iqamahByName != null ? (iqamahByName![name] ?? '') : '';
      final iqamah12  = iqamahRaw.isNotEmpty ? format12h(iqamahRaw) : '';
      final isHighlight = (highlightName != null && highlightName == name);

      // Background per theme
      final Color bg = isHighlight
          ? (isLight ? (highlightColorLight ?? highlightColor) : highlightColor)
          : (i % 2 == 0 ? rowEvenColor : rowOddColor);

      // Subtle divider only in Light
      final BoxBorder? border = isLight
          ? Border(
        bottom: BorderSide(
          color: (rowDividerColorLight ?? const Color(0xFF7B90A0).withValues(alpha: 0.16)),
          width: rowDividerThickness,
        ),
      )
          : null;

      // Arabic (display) name; glyph still uses English key
      final displayName = PrayerLabels.prayerName(context, name);

      final content = Container(
        decoration: BoxDecoration(color: bg, border: border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    displayName,
                    style: isHighlight
                        ? nameTextStyle.copyWith(fontWeight: FontWeight.w700)
                        : nameTextStyle,
                  ),
                  const SizedBox(width: 6),
                  // Brand glyph color (English key for the glyph)
                  prayerGlyph(name, color: AppColors.goldSoft),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  adhan12,
                  style: isHighlight
                      ? adhanTextStyle.copyWith(fontWeight: FontWeight.w700)
                      : adhanTextStyle,
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  iqamah12,
                  style: isHighlight
                      ? iqamahTextStyle.copyWith(fontWeight: FontWeight.w700)
                      : iqamahTextStyle,
                ),
              ),
            ),
          ],
        ),
      );

      return expandRowsToFill ? Expanded(child: content) : content;
    }

    return Column(
      children: [
        // Header row (translated)
        Container(
          decoration: headerDecoration,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Expanded(child: Text(PrayerLabels.colSalah(context),  style: headerTextStyle)),
              Expanded(child: Center(child: Text(PrayerLabels.colAdhan(context),  style: headerTextStyle))),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(PrayerLabels.colIqamah(context), style: headerTextStyle),
                ),
              ),
            ],
          ),
        ),

        // Data rows
        ...List.generate(entries.length, (i) => buildRow(entries[i], i)),
      ],
    );
  }
}