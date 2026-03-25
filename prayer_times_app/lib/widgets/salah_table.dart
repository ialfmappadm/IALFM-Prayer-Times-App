// lib/widgets/salah_table.dart
import 'dart:ui';
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

  // (optional) dark divider controls
  final Color? rowDividerColorDark;
  final double? rowDividerThicknessDark;

  // ---------------------- Glass options ----------------------
  final bool useGlassSurface;
  final double glassBlur;
  final Color? glassTintLight;
  final Color? glassTintDark;
  final Color? glassBorderLight;
  final Color? glassBorderDark;
  final double glassBorderWidth;
  final BorderRadius glassRadius;
  final bool glassUseBackdropFilter;

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
    this.rowDividerColorDark,
    this.rowDividerThicknessDark,
    this.useGlassSurface = false,
    this.glassBlur = 16,
    this.glassTintLight,
    this.glassTintDark,
    this.glassBorderLight,
    this.glassBorderDark,
    this.glassBorderWidth = 1.0,
    this.glassRadius = const BorderRadius.all(Radius.circular(18)),
    this.glassUseBackdropFilter = false,
    //this.glassUseBackdropFilter = true,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isDark  = !isLight; // readability

    // Text scale guard
    final media = MediaQuery.of(context);
    final effectiveScale = media.textScaler.scale(1.0);
    const fillRowsMaxScale = 1.15;
    final useExpandedRows = expandRowsToFill && effectiveScale <= fillRowsMaxScale;

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

    // Filter rows with adhan time
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

    // Glyph cache
    final Map<String, Widget> glyphCache = {
      'Fajr': prayerGlyph('Fajr', color: AppColors.goldSoft),
      'Sunrise': prayerGlyph('Sunrise', color: AppColors.goldSoft),
      'Dhuhr': prayerGlyph('Dhuhr', color: AppColors.goldSoft),
      'Asr': prayerGlyph('Asr', color: AppColors.goldSoft),
      'Maghrib': prayerGlyph('Maghrib', color: AppColors.goldSoft),
      // 'Isha': prayerGlyph('Isha', color: AppColors.goldSoft),
      "Jumu'ah": prayerGlyph("Jumu'ah", color: AppColors.goldSoft),
      "Youth Jumu'ah": prayerGlyph("Youth Jumu'ah", color: AppColors.goldSoft),
    };

    // Pre-format once
    final is24h = UXPrefs.use24h.value;
    String fmt(String s) => s.isEmpty ? '' : (is24h ? s : format12h(s));
    final Map<String, String> adhanFmt = {
      for (final n in entries) n: fmt(adhanByName[n] ?? ''),
    };
    final Map<String, String> iqamahFmt = {
      for (final n in entries) n: fmt((iqamahByName ?? const {})[n] ?? ''),
    };

    const rowPad = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    Widget buildRow(String name, int i) {
      final adhanText = adhanFmt[name] ?? '';
      final iqamahText = iqamahFmt[name] ?? '';
      final isHighlight = (highlightName != null && highlightName == name);

      // Transparent rows in glass mode
      final Color bg = useGlassSurface
          ? Colors.transparent
          : (isHighlight
          ? (isLight ? (highlightColorLight ?? highlightColor) : highlightColor)
          : (i.isEven ? rowEvenColor : rowOddColor));

      final double thicknessDark =
          (rowDividerThicknessDark ?? rowDividerThickness) * (useGlassSurface ? 0.8 : 1.0);

      // Hairline divider
      final BoxBorder border = Border(
        bottom: BorderSide(
          color: isLight
              ? (rowDividerColorLight ?? const Color(0xFF7B90A0).withValues(alpha: 0.16))
              .withValues(alpha: useGlassSurface ? 0.28 : 1.0)
              : (rowDividerColorDark ?? Colors.white.withValues(alpha: useGlassSurface ? 0.12 : 0.10)),
          width: isLight
              ? (useGlassSurface ? (rowDividerThickness * 0.8) : rowDividerThickness)
              : thicknessDark,
        ),
      );

      final displayName = PrayerLabels.prayerName(context, name);

      // White text/glyphs only when highlighted on dark
      final Color? forcedTextOnHighlight = (useGlassSurface && isHighlight && isDark) ? Colors.white : null;

      // Iqamah RHS
      final Widget iqamahTextOrWidget =
      (iqamahWidgetByName != null && iqamahWidgetByName!.containsKey(name))
          ? iqamahWidgetByName![name]!
          : Text(
        iqamahText,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: (isHighlight ? iqamahTextStyle.copyWith(fontWeight: FontWeight.w700) : iqamahTextStyle)
            .apply(
          color: forcedTextOnHighlight ??
              (useGlassSurface
                  ? (isLight
                  ? iqamahTextStyle.color?.withValues(alpha: 0.95)
                  : iqamahTextStyle.color?.withValues(alpha: 0.98))
                  : null),
        ),
      );

      final Widget iqamahCell = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: iqamahTextOrWidget,
      );

      // LEFT cell
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
                  style: (isHighlight ? nameTextStyle.copyWith(fontWeight: FontWeight.w700) : nameTextStyle).apply(
                    color: forcedTextOnHighlight ??
                        (useGlassSurface
                            ? (isLight
                            ? nameTextStyle.color?.withValues(alpha: 0.95)
                            : nameTextStyle.color?.withValues(alpha: 0.98))
                            : null),
                  ),
                ),
              ),
            ),
            if (name != 'Isha') ...[
              const SizedBox(width: 6),
              Align(
                alignment: Alignment.centerRight,
                child: (useGlassSurface && isHighlight && isDark)
                    ? prayerGlyph(name, color: Colors.white)
                    : (glyphCache[name] ?? prayerGlyph(name, color: AppColors.goldSoft)),
              ),
            ],
          ],
        ),
      );

      // MIDDLE cell
      final middle = Expanded(
        child: Center(
          child: Text(
            adhanText,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: (isHighlight ? adhanTextStyle.copyWith(fontWeight: FontWeight.w700) : adhanTextStyle).apply(
              color: forcedTextOnHighlight ??
                  (useGlassSurface
                      ? (isLight ? adhanTextStyle.color?.withValues(alpha: 0.98) : adhanTextStyle.color?.withValues(alpha: 1.0))
                      : null),
            ),
          ),
        ),
      );

      // RIGHT cell
      final right = Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          child: iqamahCell,
        ),
      );

      // Row scale clamp
      final rowScale = media.textScaler.scale(1.0).clamp(0.8, 1.05);
      Widget rowCore = MediaQuery(
        data: media.copyWith(textScaler: TextScaler.linear(rowScale)),
        child: Padding(
          padding: rowPad,
          child: Row(children: [left, middle, right]),
        ),
      );

      // Add hairline over background
      rowCore = DecoratedBox(
        decoration: BoxDecoration(border: border),
        child: rowCore,
      );

      // ---- Glass highlight overlay (exact pipeline mirrored): gradient + halo, no ring ----
      if (useGlassSurface && isHighlight) {
        if (isLight) {
          // GOLD (LIGHT) — unchanged
          final LinearGradient goldGradient = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (highlightColorLight ?? highlightColor).withValues(alpha: 0.30),
              (highlightColorLight ?? highlightColor).withValues(alpha: 0.22),
              (highlightColorLight ?? highlightColor).withValues(alpha: 0.28),
            ],
            stops: const [0.0, 0.5, 1.0],
          );
          final Color goldHalo = const Color(0xFFC7A447).withValues(alpha: 0.18);
          rowCore = Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.zero,
              gradient: goldGradient,
              boxShadow: [
                BoxShadow(
                  color: goldHalo,
                  blurRadius: 16,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: rowCore,
          );
        } else {
          // DARK — add a row-scoped blur to restore frosted glass ONLY on the highlight
          final LinearGradient blueGradient = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF5AA6FF).withValues(alpha: 0.52), // edge (top)
              const Color(0xFFB3DAFF).withValues(alpha: 0.36), // luminous core
              const Color(0xFF5AA6FF).withValues(alpha: 0.50), // edge (bottom)
            ],
            stops: const [0.0, 0.5, 1.0],
          );
          final Color icyHalo = const Color(0xFFCFE8FF).withValues(alpha: 0.16);

          rowCore = ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Stack(
              children: [
                // The blur is clipped to the row bounds (does NOT affect the whole table)
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: const SizedBox.expand(),
                ),
                Container(
                  decoration: BoxDecoration(
                    // subtle base wash to keep saturation on navy
                    color: const Color(0xFF5AA6FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.zero,
                    gradient: blueGradient,
                    boxShadow: [
                      BoxShadow(
                        color: icyHalo,
                        blurRadius: 22,
                        spreadRadius: 0.6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: rowCore,
                ),
              ],
            ),
          );
        }
      }

      final rowWithBg = Material(
        color: bg,
        type: useGlassSurface ? MaterialType.transparency : MaterialType.canvas,
        child: rowCore,
      );

      return useExpandedRows ? Expanded(child: rowWithBg) : rowWithBg;
    }

    // Header + rows
    Widget core = Column(
      children: [
        // Header
        Container(
          decoration: useGlassSurface
              ? BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: (rowDividerColorLight ?? const Color(0xFF7B90A0).withValues(alpha: 0.16))
                    .withValues(alpha: isLight ? 0.34 : 0.20),
                width: 0.9,
              ),
            ),
          )
              : headerDecoration,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  PrayerLabels.colSalah(context),
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: (headerTextStyle).apply(
                    color: useGlassSurface
                        ? (isLight
                        ? headerTextStyle.color?.withValues(alpha: 0.95)
                        : headerTextStyle.color?.withValues(alpha: 0.98))
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    PrayerLabels.colAdhan(context),
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: (headerTextStyle).apply(
                      color: useGlassSurface
                          ? (isLight
                          ? headerTextStyle.color?.withValues(alpha: 0.95)
                          : headerTextStyle.color?.withValues(alpha: 0.98))
                          : null,
                    ),
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
                    style: (headerTextStyle).apply(
                      color: useGlassSurface
                          ? (isLight
                          ? headerTextStyle.color?.withValues(alpha: 0.95)
                          : headerTextStyle.color?.withValues(alpha: 0.98))
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Rows
        ...List.generate(entries.length, (i) => buildRow(entries[i], i)),
      ],
    );

    if (!useGlassSurface) return core;

    // ---------- Glass wrapper (unchanged) ----------
    final Color tint = isLight
        ? (glassTintLight ?? Colors.white.withValues(alpha: 0.70))
        : (glassTintDark ?? const Color(0xFF0A1E3A).withValues(alpha: 0.46));
    final BoxBorder? panelBorder = isLight
        ? Border.all(color: (glassBorderLight ?? Colors.white.withValues(alpha: 0.85)), width: 1.0)
        : null; // no rim on dark

    final panel = Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: glassRadius,
            border: panelBorder,
          ),
          child: core,
        ),
        // top sheen (subtle; even subtler on dark)
        Positioned(
          left: 0, right: 0, top: 0, height: 14,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isLight ? 0.10 : 0.02),
                    Colors.white.withValues(alpha: 0.00),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return ClipRRect(
      borderRadius: glassRadius,
      child: glassUseBackdropFilter
          ? BackdropFilter(filter: ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur), child: panel)
          : panel,
    );
  }
}