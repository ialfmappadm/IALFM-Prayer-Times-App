// lib/widgets/salah_table.dart
import 'package:flutter/material.dart';
import 'prayer_glyphs.dart';
import '../utils/time_utils.dart';
import '../app_colors.dart';
import '../localization/prayer_labels.dart';

class SalahTable extends StatelessWidget {
  final Map<String, String> adhanByName;
  final Map<String, String>? iqamahByName;

  /// Optional widget overrides for the Iqamah column, per prayer name.
  final Map<String, Widget>? iqamahWidgetByName;

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
    this.iqamahWidgetByName,
    this.order = const ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha', "Jumu'ah"],
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

    // Read current text scale & decide if rows can expand to fill.
    // For large text sizes, stop forcing rows to fill the height to prevent vertical overflow.
    final media = MediaQuery.of(context);
    final textScale = media.textScaler.scale(1.0); // Flutter 3.13+ TextScaler
    const fillRowsMaxScale = 1.15;
    final useExpandedRows = expandRowsToFill && textScale <= fillRowsMaxScale;

    // Fallback text styles
    final headerTextStyle = headerStyle ??
        const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        );
    final nameTextStyle = nameStyle ??
        const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        );
    final adhanTextStyle = adhanStyle ??
        const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        );
    final iqamahTextStyle = iqamahStyle ??
        const TextStyle(
          color: AppColors.textMuted,
          fontSize: 16,
          fontWeight: FontWeight.w500,
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
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    )
        : (headerBackgroundGradient != null
        ? BoxDecoration(gradient: headerBackgroundGradient)
        : (headerBackgroundColor != null
        ? BoxDecoration(color: headerBackgroundColor)
        : const BoxDecoration(gradient: AppColors.headerGradient)));

    Widget buildRow(String name, int i) {
      final adhanRaw = adhanByName[name]!;
      final adhan12 = format12h(adhanRaw); // 12h English AM/PM

      final iqamahRaw = iqamahByName != null ? (iqamahByName![name] ?? '') : '';
      final iqamah12 = iqamahRaw.isNotEmpty ? format12h(iqamahRaw) : '';

      final isHighlight = (highlightName != null && highlightName == name);

      // Background per theme
      final Color bg = isHighlight
          ? (isLight ? (highlightColorLight ?? highlightColor) : highlightColor)
          : (i.isEven ? rowEvenColor : rowOddColor);

      // Subtle divider only in Light
      final BoxBorder? border = isLight
          ? Border(
        bottom: BorderSide(
          color: (rowDividerColorLight ??
              const Color(0xFF7B90A0).withValues(alpha: 0.16)),
          width: rowDividerThickness,
        ),
      )
          : null;

      // Localized (display) name; glyph still uses English key
      final displayName = PrayerLabels.prayerName(context, name);

      // ----- Iqamah (right) — scale-down guard to avoid overflow -----
      final Widget iqamahTextOrWidget =
      (iqamahWidgetByName != null && iqamahWidgetByName!.containsKey(name))
          ? iqamahWidgetByName![name]!
          : Text(
        iqamah12,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: isHighlight
            ? iqamahTextStyle.copyWith(fontWeight: FontWeight.w700)
            : iqamahTextStyle,
      );

      final Widget iqamahCell = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: iqamahTextOrWidget,
      );

      // ----- Row content -----
      final content = Container(
        decoration: BoxDecoration(color: bg, border: border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // LEFT: Salah name + glyph (glyph omitted for Isha)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Limit text scaling ONLY for the name to keep it single-line
                  // and avoid visible cropping at very large text sizes.
                  Expanded(
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(
                          MediaQuery.of(context)
                              .textScaler
                              .scale(1.0)
                              .clamp(0.8, 1.05),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          displayName,
                          maxLines: 1, // single line only
                          softWrap: false,
                          overflow: TextOverflow.ellipsis, // graceful truncation
                          style: isHighlight
                              ? nameTextStyle.copyWith(fontWeight: FontWeight.w700)
                              : nameTextStyle,
                        ),
                      ),
                    ),
                  ),

                  // Only show the prayer glyph for non-Isha prayers to avoid misplacement
                  // under large text settings. Re-enable later after layout revisit.
                  if (name != 'Isha') ...[
                    const SizedBox(width: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: prayerGlyph(name, color: AppColors.goldSoft),
                    ),
                  ],
                ],
              ),
            ),

            // MIDDLE: Adhan time (centered)
            Expanded(
              child: Center(
                child: Text(
                  adhan12,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: isHighlight
                      ? adhanTextStyle.copyWith(fontWeight: FontWeight.w700)
                      : adhanTextStyle,
                ),
              ),
            ),

            // RIGHT: Iqamah (align right)
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: iqamahCell,
              ),
            ),
          ],
        ),
      );

      // Use Expanded rows only when text is not too large.
      return useExpandedRows ? Expanded(child: content) : content;
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
              Expanded(
                child: Text(
                  PrayerLabels.colSalah(context),
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: headerTextStyle,
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    PrayerLabels.colAdhan(context),
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: headerTextStyle,
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    PrayerLabels.colIqamah(context),
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: headerTextStyle,
                  ),
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