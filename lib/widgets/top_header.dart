
// lib/widgets/top_header.dart
// Drop-in header with a single tuning knob: `donateTopPx`.
// `donateTopPx` is the distance (in pixels) from the TOP of the header
// to the centerline of the donate icon. Increase value to move icon DOWN.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:hijri/hijri_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_colors.dart';
import '../models.dart';

const double donateTopPx = 16.0; // 👈 Increase to move the icon DOWN; decrease to move UP

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
    // Gregorian date (e.g., Sat, Jan 3 2026)
    final greg = DateFormat('EEE, MMM d yyyy').format(nowLocal);

    // Hijri date via hijri_calendar
    final h = HijriCalendar.fromDate(nowLocal);
    const hijriMonths = [
      'Muharram', 'Safar', 'Rabi-al-Awwal', 'Rabi-al-Thani',
      'Jumada-al-awwal', 'Jumada-al-Thani', 'Rajab', 'Shaban',
      'Ramadan', 'Shawwal', 'Dhul-Qadah', 'Dhul-Hijjah',
    ];
    final hMonthName = (h.hMonth >= 1 && h.hMonth <= 12)
        ? hijriMonths[h.hMonth - 1]
        : 'Hijri';
    final hijriStr = '$hMonthName ${h.hDay}, ${h.hYear}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // compact
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
      ),
      child: Stack(
        children: [
          // Base content: two compact rows
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Masjid name (not bold), compact
              Text(
                'Islamic Association of Lewisville - Flower Mound',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ) ??
                    const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
              ),
              const SizedBox(height: 6),

              // Row 2: temperature (left) + centered date; reserve space on right for floating icon
              Row(
                children: [
                  // Left: temperature (no pill)
                  if (temperatureF != null)
                    Text(
                      '${temperatureF!.toStringAsFixed(0)}°F',
                      style: const TextStyle(
                        color: AppColors.goldPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),

                  // Centered date via Expanded + Center
                  Expanded(
                    child: Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            greg,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ) ??
                                const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          Text(
                            '|',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ) ??
                                const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                          ),
                          Text(
                            hijriStr,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ) ??
                                const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right spacer so the centered date doesn't collide with the floating icon
                  const SizedBox(width: 40),
                ],
              ),
            ],
          ),

          // Floating donate icon using Positioned: tune with donateTopPx (distance from top of header)
          Positioned(
            right: 0,
            top: donateTopPx, // 👈 increase to move DOWN; decrease to move UP
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
                    const SnackBar(content: Text('Could not open https://us.mohid.co/tx/dallas/ialfm/masjid/online/donation/index/1')),
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
