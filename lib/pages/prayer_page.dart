
// lib/pages/prayer_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../utils/time_utils.dart';
import '../widgets/top_header.dart';
import '../widgets/salah_table.dart';
import '../models.dart';
import '../app_colors.dart';
import '../main.dart' show AppGradients;

// NEW: labels helper for Arabic/English strings (no layout changes)
import '../localization/prayer_labels.dart';

// ---- Cool Light constants ----
const _kLightTextPrimary = Color(0xFF0F2432); // deep blue-gray
const _kLightTextMuted   = Color(0xFF4A6273);
const _kLightRowAlt      = Color(0xFFE5ECF2);
const _kLightCard        = Color(0xFFFFFFFF);
const _kLightDivider     = Color(0xFF7B90A0);
const _kLightHighlight   = Color(0xFFFFF0C9);

// Cool-blue countdown panel
const _kLightPanel       = Color(0xFFE9F2F9);
const _kLightPanelTop    = Color(0xFFDDEAF3);
const _kLightPanelBottom = Color(0xFFCBDCE8);
const _kLightGoldDigits  = Color(0xFF9C7C2C); // darker gold for legibility

const double kTempFallbackF = 72.0;

class PrayerPage extends StatefulWidget {
  final tz.Location location;
  final DateTime nowLocal;
  final PrayerDay today;
  final PrayerDay? tomorrow;
  final double? temperatureF;

  const PrayerPage({
    super.key,
    required this.location,
    required this.nowLocal,
    required this.today,
    this.tomorrow,
    this.temperatureF,
  });

  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage> {
  Timer? _ticker;
  late NextPrayerTracker _tracker;
  Duration _remaining = Duration.zero;
  NextPrayer? _next;

  @override
  void initState() {
    super.initState();
    _initTrackerAndTicker();
  }

  void _initTrackerAndTicker() {
    _tracker = NextPrayerTracker(
      loc: widget.location,
      nowLocal: DateTime.now(),
      today: widget.today,
      tomorrow: widget.tomorrow,
    );
    _next = _tracker.current;
    _remaining = _tracker.tick(DateTime.now());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        final rem = _tracker.tick(DateTime.now());
        if (!mounted) return;
        setState(() {
          _remaining = rem.isNegative ? Duration.zero : rem;
          _next = _tracker.current;
        });
      });
    });
  }

  @override
  void didUpdateWidget(covariant PrayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dayChanged =
        oldWidget.today.date != widget.today.date ||
            oldWidget.tomorrow?.date != widget.tomorrow?.date;
    final locChanged = oldWidget.location.name != widget.location.name;
    if (dayChanged || locChanged) _initTrackerAndTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // Safe title casing including Jummua'h variants (used for highlight)
  String _titleCase(String s) {
    final x = s.toLowerCase();
    switch (x) {
      case 'fajr':     return 'Fajr';
      case 'sunrise':  return 'Sunrise';
      case 'dhuhr':    return 'Dhuhr';
      case 'asr':      return 'Asr';
      case 'maghrib':  return 'Maghrib';
      case 'isha':     return 'Isha';
      case "jummua'h":
      case "jummu'ah":
      case 'jummuah':
      case 'jumuah':   return "Jummua'h";
      default:         return s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));
    }
  }

  Widget _guarded(Widget Function() build) {
    try {
      return build();
    } catch (e, st) {
      debugPrint('PrayerPage child build error: $e\n$st');
      return Container(
        color: Colors.red.shade900,
        padding: const EdgeInsets.all(16),
        child: Text('Error building widget:\n$e',
            style: const TextStyle(color: Colors.white)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight   = Theme.of(context).brightness == Brightness.light;
    final bgGradient =
        Theme.of(context).extension<AppGradients>()?.page ??
            AppColors.pageGradient;

    final next = _next;
    final remaining = _remaining.isNegative ? Duration.zero : _remaining;

    if (next == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    // Table styles
    final headerTextStyle = TextStyle(
      color: isLight ? _kLightTextPrimary : AppColors.textSecondary,
      fontSize: 16, fontWeight: FontWeight.w600,
    );
    final nameTextStyle = TextStyle(
      color: isLight ? _kLightTextPrimary : AppColors.textSecondary,
      fontSize: 16, fontWeight: FontWeight.w500,
    );
    final valueTextStyle = TextStyle(
      color: isLight ? _kLightTextPrimary : AppColors.textPrimary,
      fontSize: 16, fontWeight: FontWeight.w600,
    );

    // Countdown banner title (driven by tracker)
    final bannerTitle = PrayerLabels.countdownHeader(context, next.name);

    // Build data maps: keep English keys for glyph/ordering; labels change in SalahTable
    final adhanByName = <String, String>{
      'Fajr'    : widget.today.prayers['fajr']?.begin    ?? '',
      'Sunrise' : widget.today.sunrise                   ?? '',
      'Dhuhr'   : widget.today.prayers['dhuhr']?.begin   ?? '',
      'Asr'     : widget.today.prayers['asr']?.begin     ?? '',
      'Maghrib' : widget.today.prayers['maghrib']?.begin ?? '',
      'Isha'    : widget.today.prayers['isha']?.begin    ?? '',
      "Jummua'h": '13:30',
    };

    final iqamahByName = <String, String>{
      'Fajr'    : widget.today.prayers['fajr']?.iqamah    ?? '',
      'Sunrise' : '',
      'Dhuhr'   : widget.today.prayers['dhuhr']?.iqamah   ?? '',
      'Asr'     : widget.today.prayers['asr']?.iqamah     ?? '',
      'Maghrib' : widget.today.prayers['maghrib']?.iqamah ?? '',
      'Isha'    : widget.today.prayers['isha']?.iqamah    ?? '',
      "Jummua'h": '14:00',
    };

    // Countdown section
    final Widget countdownSection = isLight
        ? Container(
      decoration: BoxDecoration(
        color: _kLightPanel,
        border: Border(
          top:    BorderSide(color: _kLightPanelTop,    width: 1),
          bottom: BorderSide(color: _kLightPanelBottom, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            bannerTitle,
            style: const TextStyle(
              color: _kLightTextMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatCountdown(remaining),
            style: const TextStyle(
              color: _kLightGoldDigits,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    )
        : Container(
      color: AppColors.bgPrimary,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            bannerTitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatCountdown(remaining),
            style: const TextStyle(
              color: AppColors.countdownText,
              fontSize: 42,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top header (white in Light, navy in Dark)
        _guarded(() => TopHeader(
          location: widget.location,
          nowLocal: DateTime.now(),
          today: widget.today,
          tomorrow: widget.tomorrow,
          temperatureF: widget.temperatureF ?? kTempFallbackF,
        )),

        // Thin gold underline
        Container(height: 1, color: AppColors.goldDivider),

        // Countdown
        countdownSection,

        // Salah table
        Expanded(
          child: _guarded(
                () => SalahTable(
              adhanByName: adhanByName,
              iqamahByName: iqamahByName,
              highlightName: _titleCase(next.name), // English key for row highlight
              expandRowsToFill: true,

              // Header row: white in Light; navy gradient in Dark
              headerGreen: false,
              headerBackgroundGradient: isLight ? null : AppColors.headerGradient,
              headerBackgroundColor:   isLight ? Colors.white : null,

              // Rows
              rowOddColor:  isLight ? _kLightCard  : AppColors.bgSecondary,
              rowEvenColor: isLight ? _kLightRowAlt: AppColors.bgSecondary,

              // Highlight
              highlightColor:      AppColors.rowHighlight, // Dark brand
              highlightColorLight: _kLightHighlight,       // Light soft gold

              // Subtle dividers in Light
              rowDividerColorLight: _kLightDivider.withValues(alpha: 0.16),

              // Text styles
              headerStyle: headerTextStyle,
              nameStyle:   nameTextStyle,
              adhanStyle:  valueTextStyle,
              iqamahStyle: valueTextStyle,

              order: const ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha', "Jummua'h"],
            ),
          ),
        ),
      ],
    );

    // FORCE LTR on this page so nothing mirrors in Arabic
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(gradient: bgGradient),
            child: content,
          ),
        ),
      ),
    );
  }
}
