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
//const _kLightTextMuted = Color(0xFF4A6273); // secondary text

// ─────────────────────────────────────────────────────────────────────────────
// ✨ TUNABLE CONSTANTS
// 1) Header height: responsive (uses the space freed from countdown)
const double kTopHeaderMin = 120.0;
const double kTopHeaderMax = 168.0;
const double kTopHeaderTargetFraction = 0.16; // ~16% of screen height

// 2) Internal padding & spacing
const double kHeaderPaddingV = 12.0; // top/bottom of the header container
const double kHeaderPaddingH = 16.0; // left/right padding
const double kBetweenTitleRows = 8.0; // spacing between heading and dates row

// 3) Typography scale (base sizes BEFORE any scale clamp or FittedBox)
// NOTE: We’ll compute responsive sizes below; these serve as floors/ceilings.
// (was 14) → title text now scales between 16–20 depending on width.
const double kMasjidTitleSizeMin = 16.0; // NEW
const double kMasjidTitleSizeMax = 20.0; // NEW
// (was 16/18) → date line now scales between 20–24 depending on width.
const double kDateTextSizeMin = 20.0; // NEW
const double kDateTextSizeMax = 26.0; // NEW

const double kBulletSize = 18.0;
const double kTempSize = 16.0; // slightly larger for readability

// 4) Keep fixed side lanes to center the middle content
const double kSideLaneWidth = 56.0;

// 5) Accessibility text scaling policy (header‑only)
// If you want to EXCLUDE font scaling effects on the header entirely, set max=1.0.
// Default below keeps a small amount of growth for readability, but protects layout.
const double kTopHeaderMaxTextScale = 1.10; // set to 1.00 to fully ignore scaling

// 6) Countdown digit colors (for matching the temperature)
// Light theme digits deep gold that reads well on white; dark uses app‑defined.
const Color kCountdownGoldLight = Color(0xFF9C7C2C);

const Offset kDonateNudge = Offset(8, -2); // right 8px, up 2px (your chosen placement)
const double kRightLaneMinWidth = 44.0;    // prevent the lane/tap target from feeling cramped


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
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Gregorian (left of the bullet)
    final greg = DateFormat('EEE, MMM d yyyy').format(nowLocal);

    // Apply effective offset BEFORE converting to Hijri (base + user)
    final int effOffsetDays = UXPrefs.hijriEffectiveOffset;
    final DateTime hijriAdjusted = nowLocal.add(Duration(days: effOffsetDays));
    final h = HijriCalendar.fromDate(hijriAdjusted);
    const hijriMonths = [
      'Muharram','Safar','Rabi-al-Awwal','Rabi-al-Thani',
      'Jumada-al-awwal','Jumada-al-Thani','Rajab','Shaban',
      'Ramadan','Shawwal','Dhul-Qadah','Dhul-Hijjah',
    ];
    final hMonthName = (h.hMonth >= 1 && h.hMonth <= 12) ? hijriMonths[h.hMonth - 1] : 'Hijri';
    final hijriStr = '$hMonthName ${h.hDay}, ${h.hYear}';

    // Background (same logic)
    final decoration = isLight
        ? const BoxDecoration(color: Colors.white)
        : const BoxDecoration(gradient: AppColors.headerGradient);

    final titleColor = isLight ? _kLightTextPrimary : AppColors.textSecondary;
    final dateColor  = isLight ? _kLightTextPrimary : AppColors.textPrimary;
    //final bulletColor = isLight ? _kLightTextMuted : AppColors.textSecondary;

    // RMatch the temperature color to the countdown digits
    final Color tempColor = isLight ? kCountdownGoldLight : AppColors.countdownText;

    // ── Responsive height to occupy space you freed in countdown ─────────────
    final media = MediaQuery.of(context);
    final screenW = media.size.width;                      // NEW
    final screenH = media.size.height;
    final topHeaderHeight =
    (screenH * kTopHeaderTargetFraction).clamp(kTopHeaderMin, kTopHeaderMax);

    // ── Clamp text scaling inside the header so large accessibility sizes don’t overflow
    // NOTE: set kTopHeaderMaxTextScale=1.0 if you want this header to fully ignore scaling.
    final clamped = media.textScaler.clamp(maxScaleFactor: kTopHeaderMaxTextScale);

    // ── Responsive font sizes (simple width thresholds) ──────────────────────
    // Wider screens → larger base font; narrow screens → slightly smaller.
    // These values are BEFORE the FittedBox(scaleDown) safeguard kicks in.
    final double titleSize = (screenW >= 430.0)
        ? kMasjidTitleSizeMax
        : (screenW >= 380.0)
        ? 18.0
        : kMasjidTitleSizeMin;

    final double dateSizeBase = (screenW >= 430.0)
        ? kDateTextSizeMax
        : (screenW >= 380.0)
        ? 22.0
        : kDateTextSizeMin;

    // Ensure the date is never larger than the title on wide screens
    final double dateSize = (dateSizeBase > titleSize) ? titleSize : dateSizeBase;

    // ── Responsive side lanes (give center date more width on small phones) ──
    final double sideLaneW = (screenW < 360.0)
        ? 48.0
        : (screenW < 400.0)
        ? 52.0
        : kSideLaneWidth;

    // Shrink the right lane by the horizontal nudge so the center Expanded grows.
    // (kDonateNudge.dx is +8 → lane becomes sideLaneW - 8)
    final double rightLaneW =
    (sideLaneW - kDonateNudge.dx).clamp(kRightLaneMinWidth, sideLaneW);

    // Compose the one-line dates as a SINGLE Text (no wrapping),
    // then let FittedBox scale down to fit.
    final oneLineDates = Text(
      // Single line string
      '$greg • $hijriStr',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible, // scale down instead of ellipsizing
      textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium?.copyWith(
        color: dateColor,
        fontWeight: FontWeight.w700, // slightly bolder for better readability
        fontSize: dateSize,          // ← responsive
        letterSpacing: 0.15,
      ) ??
          TextStyle(
            color: dateColor,
            fontSize: dateSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.15,
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
        fontWeight: FontWeight.w700,
        fontSize: titleSize, // ← responsive
        letterSpacing: 0.2,
      ) ??
          TextStyle(
            color: titleColor,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
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
              const SizedBox(height: kBetweenTitleRows),

              // ── One-line dates: stay on one line and scale down to fit ──────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // LEFT lane: temperature in fixed (responsive) width box
                  SizedBox(
                    width: sideLaneW, // ← responsive
                    child: (temperatureF != null)
                        ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${temperatureF!.toStringAsFixed(0)}°F',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          color: tempColor, // ← matches countdown
                          fontSize: kTempSize, // 16.0
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

                  // RIGHT lane: donate icon in fixed (responsive) width (mirrors left)
                  SizedBox(
                    width: rightLaneW, // ← use adjusted lane width so center can expand
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Transform.translate(
                        offset: kDonateNudge, // ← your chosen placement (8, -2)
                        child: IconButton(
                          icon: const Icon(
                            Icons.volunteer_activism,
                            color: AppColors.goldPrimary,
                          ),

                          tooltip: 'Donate',
                          padding: EdgeInsets.zero, // stable lane width
                          alignment: Alignment.center,
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
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
