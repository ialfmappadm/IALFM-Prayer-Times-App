
// lib/widgets/salah_table.dart
import 'package:flutter/material.dart';
import 'prayer_glyphs.dart';
import '../utils/time_utils.dart';
import '../app_colors.dart';

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
  final Color highlightColor;

  // Layout options
  final bool expandRowsToFill;

  // Header visuals
  final bool headerGreen; // if true, force classic green header
  final Gradient? headerBackgroundGradient; // preferred gradient when headerGreen=false
  final Color? headerBackgroundColor;      // preferred solid color when headerGreen=false

  const SalahTable({
    super.key,
    required this.adhanByName,
    this.iqamahByName,
    this.order = const ['Fajr','Sunrise','Dhuhr','Asr','Maghrib','Isha','Jummuah'],
    this.highlightName,
    this.headerStyle,
    this.nameStyle,
    this.adhanStyle,
    this.iqamahStyle,
    this.rowEvenColor = AppColors.bgSecondary,
    this.rowOddColor = AppColors.bgSecondary,
    this.highlightColor = AppColors.rowHighlight,
    this.expandRowsToFill = false,
    this.headerGreen = false,
    this.headerBackgroundGradient,
    this.headerBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
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

    // Filter to only entries that have an Adhan time
    final entries = order.where((n) {
      final v = adhanByName[n];
      return v != null && v.isNotEmpty;
    }).toList();

    // Helper: build a single data row
    Widget buildRow(String name, int i) {
      final adhanRaw = adhanByName[name]!;
      final adhan12 = format12h(adhanRaw);
      final iqamahRaw = iqamahByName != null ? (iqamahByName![name] ?? '') : '';
      final iqamah12 = iqamahRaw.isNotEmpty ? format12h(iqamahRaw) : '';
      final isHighlight = (highlightName != null && highlightName == name);

      final bg = isHighlight
          ? highlightColor
          : (i % 2 == 0 ? rowEvenColor : rowOddColor);

      final content = Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    name,
                    style: isHighlight
                        ? nameTextStyle.copyWith(fontWeight: FontWeight.w700)
                        : nameTextStyle,
                  ),
                  const SizedBox(width: 6),
                  // Use gold-soft accents for glyphs to match the palette
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

    // Decide header decoration: green override, custom gradient/color, or app default gradient
    final BoxDecoration? headerDecoration = headerGreen
        ? const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF2E7D32), Color(0xFF388E3C)], // classic green
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    )
        : (headerBackgroundGradient != null
        ? BoxDecoration(gradient: headerBackgroundGradient)
        : (headerBackgroundColor != null
        ? BoxDecoration(color: headerBackgroundColor)
        : const BoxDecoration(gradient: AppColors.headerGradient)));

    return Column(
      children: [
        // ── Header row
        Container(
          decoration: headerDecoration,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Expanded(child: Text('Salah', style: headerTextStyle)),
              Expanded(child: Center(child: Text('Adhan', style: headerTextStyle))),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('Iqamah', style: headerTextStyle),
                ),
              ),
            ],
          ),
        ),
        // ── Data rows
        ...List.generate(entries.length, (i) => buildRow(entries[i], i)),
      ],
    );
  }
}
