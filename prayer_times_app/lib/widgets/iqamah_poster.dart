import 'package:flutter/material.dart';
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';
import '../app_colors.dart';
import '../localization/prayer_labels.dart';
import '../models.dart';

class IqamahPoster extends StatelessWidget {
  const IqamahPoster({
    super.key,
    required this.day,
    required this.isLight,
    required this.dstOn,
    required this.to12h,
    required this.l10n,
    required this.maghribText,
    required this.adhanMap,
    required this.iqamahMap,
    required this.firstKhateeb,
    required this.youthKhateeb,
  });

  final PrayerDay day;
  final bool isLight;
  final bool dstOn;
  final String Function(String raw) to12h;
  final AppLocalizations l10n;
  final String maghribText;
  final Map<String, String> adhanMap;
  final Map<String, String> iqamahMap;
  final String firstKhateeb;
  final String youthKhateeb;

  @override
  Widget build(BuildContext context) {
    final glassTint = isLight
        ? Colors.white.withValues(alpha: 0.70)
        : const Color(0xFF0A1E3A).withValues(alpha: 0.28);

    // Typography
    final headerStyle = TextStyle(
      color: isLight ? const Color(0xFF0F2432) : AppColors.textSecondary,
      fontSize: 18, fontWeight: FontWeight.w800,
    );
    final sectionStyle = TextStyle(
      color: isLight ? const Color(0xFF0F2432) : AppColors.textSecondary,
      fontSize: 16.5, fontWeight: FontWeight.w600, letterSpacing: 0.2,
    );
    final nameStyle = TextStyle(
      color: isLight ? const Color(0xFF0F2432) : AppColors.textSecondary,
      fontSize: 16, fontWeight: FontWeight.w700,
    );
    final valueStyle = TextStyle(
      color: isLight ? const Color(0xFF0F2432) : AppColors.textPrimary,
      fontSize: 16, fontWeight: FontWeight.w700,
    );
    final subNameStyle = nameStyle.copyWith(
      fontSize: 15.0, fontWeight: FontWeight.w600,
      color: (isLight ? const Color(0xFF0F2432) : AppColors.textSecondary).withValues(alpha: 0.92),
    );

    final compact = dstOn;
    final rowVPad = compact ? 8.0 : 12.0;
    final subRowVPad = compact ? 6.0 : 10.0;
    final sectionTop = compact ? 6.0 : 10.0;
    final sectionBot = compact ? 4.0 : 6.0;

    String t(String? s) => (s == null || s.isEmpty) ? '—' : to12h(s);

    final fajr    = t(day.prayers['fajr']?.iqamah);
    final dhuhr   = t(day.prayers['dhuhr']?.iqamah);
    final asr     = t(day.prayers['asr']?.iqamah);
    final maghrib = maghribText; // “Sunset + 5 mins”
    final isha    = t(day.prayers['isha']?.iqamah);

    final mainKhutbah  = to12h(adhanMap["Jumu'ah"] ?? '13:30');
    final mainIqamah   = to12h(iqamahMap["Jumu'ah"] ?? '14:00');
    final youthKhutbah = dstOn ? to12h(adhanMap["Youth Jumu'ah"] ?? '16:00') : '';
    final youthIqamah  = dstOn ? to12h(iqamahMap["Youth Jumu'ah"] ?? '16:15') : '';

    Widget divider([double alpha = 0.25]) => Divider(
      height: 0, thickness: 0.8,
      color: isLight ? const Color(0xFF7B90A0).withValues(alpha: alpha)
          : Colors.white.withValues(alpha: 0.10),
    );

    Widget header() => Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: rowVPad),
      child: Center(
        child: Text(
          l10n.label_iqamah_times,
          style: headerStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    // Generic row: single line on both sides
    Widget row(String left, String right) => Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: rowVPad),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(left, style: nameStyle, maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                right,
                style: valueStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );

    // ✅ Special row: give RIGHT column (name) more width and keep it single-line.
    // Left label compresses earlier and ellipsizes if needed.
    Widget rowRightPriority(String left, String right) => Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: rowVPad),
      child: Row(
        children: [
          // Left label with SMALLER flex, still allowed to ellipsize
          Expanded(
            flex: 3,
            child: Text(
              left,
              style: nameStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Right value (name) with LARGER flex → takes more width; stays single-line
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                right,
                style: valueStyle,
                maxLines: 1,               // ← never wraps
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );

    Widget subRow(String left, String right) => Padding(
      padding: EdgeInsets.fromLTRB(28, subRowVPad, 16, subRowVPad),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(left, style: subNameStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(right, style: valueStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );

    Widget section(String title) => Padding(
      padding: EdgeInsets.fromLTRB(16, sectionTop, 16, sectionBot),
      child: Text(title, style: sectionStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    return DecoratedBox(
      decoration: BoxDecoration(color: glassTint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header(), divider(),
          row(PrayerLabels.prayerName(context, 'Fajr'),    fajr),    divider(),
          row(PrayerLabels.prayerName(context, 'Dhuhr'),   dhuhr),   divider(),
          row(PrayerLabels.prayerName(context, 'Asr'),     asr),     divider(),
          row(PrayerLabels.prayerName(context, 'Maghrib'), maghrib), divider(),
          row(PrayerLabels.prayerName(context, 'Isha'),    isha),    divider(),

          section(PrayerLabels.prayerName(context, "Jumu'ah")),
          subRow(l10n.label_khutbah, mainKhutbah), divider(0.18),
          subRow(l10n.label_iqamah, mainIqamah),   divider(),

          // ✅ Main Khateeb: right-side single-line with priority width
          rowRightPriority(
            l10n.label_first_khateeb,
            firstKhateeb.trim().isEmpty ? l10n.label_unknown_tbd : firstKhateeb.trim(),
          ),
          divider(),

          if (dstOn) ...[
            section(PrayerLabels.prayerName(context, "Youth Jumu'ah")),
            subRow(l10n.label_khutbah, youthKhutbah), divider(0.18),
            subRow(l10n.label_iqamah, youthIqamah),   divider(),

            // ✅ Youth Khateeb: right-side single-line with priority width
            rowRightPriority(
              l10n.label_youth_khateeb,
              youthKhateeb.trim().isEmpty ? l10n.label_unknown_tbd : youthKhateeb.trim(),
            ),
            divider(),
          ],
        ],
      ),
    );
  }
}