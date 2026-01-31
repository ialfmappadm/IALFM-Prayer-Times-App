// lib/widgets/salah_table.dart
import 'package:flutter/material.dart';
import 'prayer_glyphs.dart';
import '../utils/time_utils.dart';
import '../app_colors.dart';
import '../localization/prayer_labels.dart';
import '../ux_prefs.dart'; // <-- for 12/24h

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

    // Text scale guard → avoid vertical overflow at very large sizes
    final media = MediaQuery.of(context);
    final effectiveScale = media.textScaler.scale(1.0);
    const fillRowsMaxScale = 1.15;
    final useExpandedRows = expandRowsToFill && effectiveScale <= fillRowsMaxScale;

    // Fallback text styles (honor injected styles if provided)
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
    final BoxDecoration headerDecoration = headerGreen
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

    // ----- Glyph cache reused across rows this build (no behavior change) -----
    final Map<String, Widget> glyphCache = {
      'Fajr': prayerGlyph('Fajr', color: AppColors.goldSoft),
      'Sunrise': prayerGlyph('Sunrise', color: AppColors.goldSoft),
      'Dhuhr': prayerGlyph('Dhuhr', color: AppColors.goldSoft),
      'Asr': prayerGlyph('Asr', color: AppColors.goldSoft),
      'Maghrib': prayerGlyph('Maghrib', color: AppColors.goldSoft),
      // You intentionally omit Isha’s moon glyph to avoid misplacement at very large scales.
      // 'Isha': prayerGlyph('Isha', color: AppColors.goldSoft),
      "Jumu'ah": prayerGlyph("Jumu'ah", color: AppColors.goldSoft),
      "Youth Jumu'ah": prayerGlyph("Youth Jumu'ah", color: AppColors.goldSoft),
    };

    // ----- Pre-format times once per build (avoid repeated work in every row) -----
    final is24h = UXPrefs.use24h.value;
    String fmt(String s) => s.isEmpty ? '' : (is24h ? s : format12h(s));

    final Map<String, String> adhanFmt = {
      for (final n in entries) n: fmt(adhanByName[n] ?? ''),
    };
    final Map<String, String> iqamahFmt = {
      for (final n in entries) n: fmt((iqamahByName ?? const {})[n] ?? ''),
    };

    // Reuse a single const row padding (micro allocation win)
    const rowPad = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    Widget buildRow(String name, int i) {
      final adhanText = adhanFmt[name] ?? '';
      final iqamahText = iqamahFmt[name] ?? '';
      final isHighlight = (highlightName != null && highlightName == name);

      // Opaque row background per theme (ensures cheap composition)
      final Color bg = isHighlight
          ? (isLight ? (highlightColorLight ?? highlightColor) : highlightColor)
          : (i.isEven ? rowEvenColor : rowOddColor);

      // Subtle divider only in Light
      final BoxBorder? border = isLight
          ? Border(
        bottom: BorderSide(
          color: (rowDividerColorLight ?? const Color(0xFF7B90A0).withValues(alpha: 0.16)),
          width: rowDividerThickness,
        ),
      )
          : null;

      // Localized (display) name; glyph still uses English key
      final displayName = PrayerLabels.prayerName(context, name);

      // Right cell: prefer widget override when provided (e.g., Sunrise DST pill)
      final Widget iqamahTextOrWidget =
      (iqamahWidgetByName != null && iqamahWidgetByName!.containsKey(name))
          ? iqamahWidgetByName![name]!
          : Text(
        iqamahText,
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

      // LEFT: name + glyph
      final left = Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  displayName,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: isHighlight
                      ? nameTextStyle.copyWith(fontWeight: FontWeight.w700)
                      : nameTextStyle,
                ),
              ),
            ),
            if (name != 'Isha') ...[
              const SizedBox(width: 6),
              Align(
                alignment: Alignment.centerRight,
                child: glyphCache[name] ?? prayerGlyph(name, color: AppColors.goldSoft),
              ),
            ],
          ],
        ),
      );

      // MIDDLE: Adhan
      final middle = Expanded(
        child: Center(
          child: Text(
            adhanText,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: isHighlight
                ? adhanTextStyle.copyWith(fontWeight: FontWeight.w700)
                : adhanTextStyle,
          ),
        ),
      );

      // RIGHT: Iqamah
      final right = Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: iqamahCell,
        ),
      );

      // ---- One MediaQuery clamp for the **entire row** (0.8–1.05), not per cell ----
      final rowScale = media.textScaler.scale(1.0).clamp(0.8, 1.05);

      Widget rowCore = MediaQuery(
        data: media.copyWith(textScaler: TextScaler.linear(rowScale)),
        child: Padding(
          padding: rowPad,
          child: Row(children: [left, middle, right]),
        ),
      );

      // Optional hairline border on top of the opaque background
      if (border != null) {
        rowCore = DecoratedBox(
          decoration: BoxDecoration(border: border),
          child: rowCore,
        );
      }

      // Paint row with an opaque background (cheaper than translucent compositing)
      final rowWithBg = Material(color: bg, child: rowCore);

      return useExpandedRows ? Expanded(child: rowWithBg) : rowWithBg;
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