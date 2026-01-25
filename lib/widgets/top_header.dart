
// lib/widgets/top_header.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:hijri/hijri_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../models.dart';

// Cool Light palette bits
const _kLightTextPrimary = Color(0xFF0F2432); // deep blue-gray
const _kLightTextMuted   = Color(0xFF4A6273); // secondary text

const double donateTopPx = 16.0;

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

    final greg = DateFormat('EEE, MMM d yyyy').format(nowLocal);
    final h = HijriCalendar.fromDate(nowLocal);
    const hijriMonths = [
      'Muharram','Safar','Rabi-al-Awwal','Rabi-al-Thani',
      'Jumada-al-awwal','Jumada-al-Thani','Rajab','Shaban',
      'Ramadan','Shawwal','Dhul-Qadah','Dhul-Hijjah',
    ];
    final hMonthName = (h.hMonth >= 1 && h.hMonth <= 12)
        ? hijriMonths[h.hMonth - 1] : 'Hijri';
    final hijriStr = '$hMonthName ${h.hDay}, ${h.hYear}';

    // Header background: Light → white; Dark → navy gradient
    final decoration = isLight
        ? const BoxDecoration(color: Colors.white)
        : const BoxDecoration(gradient: AppColors.headerGradient);

    final titleColor  = isLight ? _kLightTextPrimary : AppColors.textSecondary;
    final dateColor   = isLight ? _kLightTextPrimary : AppColors.textPrimary;
    final bulletColor = isLight ? _kLightTextMuted   : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: decoration,
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Masjid name
              Text(
                'Islamic Association of Lewisville - Flower Mound',
                textAlign: TextAlign.center,
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

              // Temp (left) + dates (center); right reserved for donate icon
              Row(
                children: [
                  if (temperatureF != null) const SizedBox(width: 2),
                  if (temperatureF != null)
                    Text(
                      '${temperatureF!.toStringAsFixed(0)}°F',
                      style: const TextStyle(
                        color: AppColors.goldPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
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
                  const SizedBox(width: 40),
                ],
              ),
            ],
          ),

          // Donate icon (gold)
          Positioned(
            right: 0,
            top: donateTopPx,
            child: IconButton(
              icon: const Icon(Icons.volunteer_activism, color: AppColors.goldPrimary),
              tooltip: 'Donate',
              onPressed: () async {
                final ok = await launchUrl(
                  Uri.parse('https://us.mohid.co/tx/dallas/ialfm/masjid/online/donation/index/1'),
                  mode: LaunchMode.externalApplication,
                );
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open https://us.mohid.co/tx/dallas/ialfm/masjid/online/donation/index/1'),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
