// lib/widgets/top_header.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:hijri/hijri_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../models.dart';
import '../ux_prefs.dart';

/// Light theme text colors (as in your original)
const _kLightTextPrimary = Color(0xFF0F2432); // deep blue-gray
const _kLightTextMuted   = Color(0xFF4A6273); // secondary text

// ─────────────────────────────────────────────────────────────────────────────
// ✨ TUNABLE CONSTANTS

// 1) Header height: responsive (uses the space freed from countdown)
const double kTopHeaderMin = 120.0;
const double kTopHeaderMax = 168.0;
const double kTopHeaderTargetFraction = 0.16; // ~16% of screen height

// 2) Internal padding & spacing
const double kHeaderPaddingV   = 12.0; // top/bottom of the header container
const double kHeaderPaddingH   = 16.0; // left/right padding
const double kBetweenTitleRows = 8.0;  // spacing between heading and dates row

// 3) Typography scale (base sizes BEFORE any scale clamp or FittedBox)
const double kMasjidTitleSize  = 16.0; // (was 14)
const double kDateTextSize     = 18.0; // (was 16)
const double kBulletSize       = 18.0;
const double kTempSize         = 16.0; // slightly larger for readability

// 4) Keep fixed side lanes to center the middle content
const double kSideLaneWidth = 56.0;

// 5) Accessibility text scaling policy (header‑only)
// If you want to EXCLUDE font scaling effects on the header entirely, set max=1.0.
// Default below keeps a small amount of growth for readability, but protects layout.
const double kTopHeaderMaxTextScale = 1.10; // set to 1.00 to fully ignore scaling

// 6) Countdown digit colors (for matching the temperature)
// Light theme digits deep gold that reads well on white; dark uses app-defined.
const Color kCountdownGoldLight = Color(0xFF9C7C2C);
// ─────────────────────────────────────────────────────────────────────────────

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
    final theme   = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Gregorian (left of the bullet)
    final greg = DateFormat('EEE, MMM d yyyy').format(nowLocal);

    // Apply effective offset BEFORE converting to Hijri (base + user)
    final int effOffsetDays     = UXPrefs.hijriEffectiveOffset;
    final DateTime hijriAdjusted = nowLocal.add(Duration(days: effOffsetDays));
    final h = HijriCalendar.fromDate(hijriAdjusted);

    const hijriMonths = [
      'Muharram','Safar','Rabi-al-Awwal','Rabi-al-Thani',
      'Jumada-al-awwal','Jumada-al-Thani','Rajab','Shaban',
      'Ramadan','Shawwal','Dhul-Qadah','Dhul-Hijjah',
    ];
    final hMonthName = (h.hMonth >= 1 && h.hMonth <= 12) ? hijriMonths[h.hMonth - 1] : 'Hijri';
    final hijriStr   = '$hMonthName ${h.hDay}, ${h.hYear}';

    // Background (same logic)
    final decoration = isLight
        ? const BoxDecoration(color: Colors.white)
        : const BoxDecoration(gradient: AppColors.headerGradient);

    final titleColor  = isLight ? _kLightTextPrimary : AppColors.textSecondary;
    final dateColor   = isLight ? _kLightTextPrimary : AppColors.textPrimary;
    final bulletColor = isLight ? _kLightTextMuted   : AppColors.textSecondary;

    // 🔶 Match the temperature color to the countdown digits
    final Color tempColor = isLight ? kCountdownGoldLight : AppColors.countdownText;

    // ── Responsive height to occupy space you freed in countdown ─────────────
    final screenH         = MediaQuery.of(context).size.height;
    final topHeaderHeight =
    (screenH * kTopHeaderTargetFraction).clamp(kTopHeaderMin, kTopHeaderMax);

    // ── Clamp text scaling inside the header so large accessibility sizes don’t overflow
    // NOTE: set kTopHeaderMaxTextScale=1.0 if you want this header to fully ignore scaling.
    final media = MediaQuery.of(context);
    final clamped = media.textScaler.clamp(maxScaleFactor: kTopHeaderMaxTextScale);

    // Compose the one-line dates as a SINGLE Text (no wrapping), then let FittedBox scale down to fit.
    final oneLineDates = Text(
      // Single line string
      '$greg  •  $hijriStr',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible, // scale down instead of ellipsizing
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium?.copyWith(
        color: dateColor,
        fontWeight: FontWeight.w600,
        fontSize: kDateTextSize,
      ) ??
          TextStyle(
            color: dateColor,
            fontSize: kDateTextSize,
            fontWeight: FontWeight.w600,
          ),
    );

    // Heading text that must never crop; scale it down if needed
    final heading = Text(
      'Islamic Association of Lewisville - Flower Mound',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible, // scale down instead of ellipsizing
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium?.copyWith(
        color: titleColor,
        fontWeight: FontWeight.w600,
        fontSize: kMasjidTitleSize,
      ) ??
          TextStyle(
            color: titleColor,
            fontSize: kMasjidTitleSize,
            fontWeight: FontWeight.w600,
          ),
    );

    return MediaQuery(
      // Clamp scaling for the header subtree only
      data: media.copyWith(textScaler: clamped),
      child: SizedBox(
        height: topHeaderHeight,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: kHeaderPaddingH,
            vertical: kHeaderPaddingV,
          ),
          decoration: decoration,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Never-crop heading: FittedBox scales down to fit width ─────
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: heading,
                ),
              ),

              SizedBox(height: kBetweenTitleRows),

              // ── One-line dates: stay on one line and scale down to fit ──────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // LEFT lane: temperature in fixed width box
                  SizedBox(
                    width: kSideLaneWidth,
                    child: (temperatureF != null)
                        ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${temperatureF!.toStringAsFixed(0)}°F',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          color: tempColor,            // ← matches countdown
                          fontSize: kTempSize,         // 16.0
                          fontWeight: FontWeight.w800, // bold enough without noise
                          letterSpacing: 0.2,
                          height: 1.0,
                        ),
                      ),
                    )
                        : const SizedBox.shrink(),
                  ),

                  // CENTER lane (Expanded): dates in a FittedBox, single Text
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: oneLineDates,
                      ),
                    ),
                  ),

                  // RIGHT lane: donate icon in fixed width (mirrors left)
                  SizedBox(
                    width: kSideLaneWidth,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(
                          Icons.volunteer_activism,
                          color: AppColors.goldPrimary,
                        ),
                        tooltip: 'Donate',
                        padding: EdgeInsets.zero,   // stable width 56 px lane
                        alignment: Alignment.center, // centered in lane
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
        ),
      ),
    );
  }
}