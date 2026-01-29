// lib/widgets/top_header.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:hijri/hijri_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../models.dart';
import '../ux_prefs.dart';

/// Light theme text colors
const _kLightTextPrimary = Color(0xFF0F2432); // deep blue-gray
const _kLightTextMuted   = Color(0xFF4A6273); // secondary text

class TopHeader extends StatelessWidget {
  final tz.Location location;
  final DateTime nowLocal;
  final PrayerDay today;
  final PrayerDay? tomorrow;
  final double? temperatureF;

  const TopHeader({
    super.key,
    required this.location,
    required this.nowLocal,
    required this.today,
    this.tomorrow,
    this.temperatureF,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Gregorian date (left of the center bullet)
    final greg = DateFormat('EEE, MMM d yyyy').format(nowLocal);

    // Apply effective offset BEFORE converting to Hijri (base + user)
    final int effOffsetDays = UXPrefs.hijriEffectiveOffset;
    final DateTime adjustedForHijri = nowLocal.add(Duration(days: effOffsetDays));
    final h = HijriCalendar.fromDate(adjustedForHijri);

    const hijriMonths = [
      'Muharram','Safar','Rabi-al-Awwal','Rabi-al-Thani',
      'Jumada-al-awwal','Jumada-al-Thani','Rajab','Shaban',
      'Ramadan','Shawwal','Dhul-Qadah','Dhul-Hijjah',
    ];
    final hMonthName = (h.hMonth >= 1 && h.hMonth <= 12)
        ? hijriMonths[h.hMonth - 1]
        : 'Hijri';
    final hijriStr = '$hMonthName ${h.hDay}, ${h.hYear}';

    // Header background
    final decoration = isLight
        ? const BoxDecoration(color: Colors.white)
        : const BoxDecoration(gradient: AppColors.headerGradient);

    final titleColor  = isLight ? _kLightTextPrimary : AppColors.textSecondary;
    final dateColor   = isLight ? _kLightTextPrimary : AppColors.textPrimary;
    final bulletColor = isLight ? _kLightTextMuted   : AppColors.textSecondary;

    // Fixed lane width on both sides keeps center truly centered
    const sideLaneWidth = 56.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Masjid name
          Text(
            'Islamic Association of Lewisville - Flower Mound',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ) ??
                TextStyle(
                  color: titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),

          // One Row: [left fixed lane] [center Expanded dates] [right fixed lane]
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LEFT lane: temperature (or empty) in a fixed-width box
              SizedBox(
                width: sideLaneWidth,
                child: (temperatureF != null)
                    ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${temperatureF!.toStringAsFixed(0)}°F',
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: const TextStyle(
                      color: AppColors.goldPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                )
                    : const SizedBox.shrink(),
              ),

              // CENTER lane: dates; wrap so the row can grow vertically on small screens
              Expanded(
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      Text(
                        greg,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: dateColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ) ??
                            TextStyle(
                              color: dateColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        '•',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: bulletColor,
                          fontSize: 16,
                        ) ??
                            TextStyle(
                              color: bulletColor,
                              fontSize: 16,
                            ),
                      ),
                      Text(
                        hijriStr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: dateColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ) ??
                            TextStyle(
                              color: dateColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              // RIGHT lane: donate icon in a fixed-width box (mirrors the left)
              SizedBox(
                width: sideLaneWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(
                      Icons.volunteer_activism,
                      color: AppColors.goldPrimary,
                    ),
                    tooltip: 'Donate',
                    padding: EdgeInsets.zero,      // NO extra padding = stable width
                    alignment: Alignment.center,   // centered within the 56x56 lane
                    splashRadius: 22,
                    onPressed: () async {
                      final ok = await launchUrl(
                        Uri.parse(
                          'https://us.mohid.co/tx/dallas/ialfm/masjid/online/donation/index/1',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not open https://us.mohid.co/tx/dallas/ialfm/masjid/online/donation/index/1',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
