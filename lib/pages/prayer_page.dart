
// lib/pages/prayer_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../utils/time_utils.dart'; // getNextPrayer, formatCountdown, format12h
import '../widgets/top_header.dart';
import '../widgets/salah_table.dart';
import '../models.dart';
import '../app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    // Start after first frame to avoid any pre-paint jank.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _titleCase(String s) {
    switch (s.toLowerCase()) {
      case 'fajr': return 'Fajr';
      case 'sunrise': return 'Sunrise';
      case 'dhuhr': return 'Dhuhr';
      case 'asr': return 'Asr';
      case 'maghrib': return 'Maghrib';
      case 'isha': return 'Isha';
      case "jummua'h": return "Jummua'h";
      case 'jumuah': return 'Jumuah';
      default: return s;
    }
  }

  // Guarded builder to surface child build errors on-screen.
  Widget _guarded(Widget Function() build) {
    try {
      return build();
    } catch (e, st) {
      debugPrint('PrayerPage child build error: $e\n$st');
      return Container(
        color: Colors.red.shade900,
        padding: const EdgeInsets.all(16),
        child: Text(
          'Error building widget:\n$e',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use now from clock; avoid costly recomputation inside children each tick.
    final nowLocal = DateTime.now();

    final next = getNextPrayer(widget.location, nowLocal, widget.today, widget.tomorrow);
    final tzNow = tz.TZDateTime.from(nowLocal, widget.location);

    // Clamp negative durations to zero to avoid format errors.
    final remainingRaw = next.time.difference(tzNow);
    final remaining = remainingRaw.isNegative ? Duration.zero : remainingRaw;

    final bannerTitle = '${_titleCase(next.name)} Adhan in…';

    final adhanByName = <String, String>{
      'Fajr'   : widget.today.prayers['fajr']?.begin ?? '',
      'Sunrise': widget.today.sunrise ?? '',
      'Dhuhr'  : widget.today.prayers['dhuhr']?.begin ?? '',
      'Asr'    : widget.today.prayers['asr']?.begin ?? '',
      'Maghrib': widget.today.prayers['maghrib']?.begin ?? '',
      'Isha'   : widget.today.prayers['isha']?.begin ?? '',
      "Jummua'h" : '13:30', // static
    };

    final iqamahByName = <String, String>{
      'Fajr'   : widget.today.prayers['fajr']?.iqamah ?? '',
      'Sunrise': '', // no iqamah for sunrise
      'Dhuhr'  : widget.today.prayers['dhuhr']?.iqamah ?? '',
      'Asr'    : widget.today.prayers['asr']?.iqamah ?? '',
      'Maghrib': widget.today.prayers['maghrib']?.iqamah ?? '',
      'Isha'   : widget.today.prayers['isha']?.iqamah ?? '',
      "Jummua'h" : '14:00', // static
    };

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _guarded(() => TopHeader(
          location: widget.location,
          nowLocal: nowLocal,
          today: widget.today,
          tomorrow: widget.tomorrow,
          temperatureF: widget.temperatureF ?? kTempFallbackF,
        )),

        // Thin gold divider under header
        Container(height: 1, color: AppColors.goldDivider),

        // Countdown banner area (navy background)
        Container(
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
        ),

        // Table fills the rest of the screen
        Expanded(
          child: _guarded(() => SalahTable(
            adhanByName: adhanByName,
            iqamahByName: iqamahByName,
            highlightName: _titleCase(next.name),
            expandRowsToFill: true,
            headerGreen: false,
            headerBackgroundGradient: AppColors.headerGradient,
            rowEvenColor: AppColors.bgSecondary,
            rowOddColor: AppColors.bgSecondary,
            highlightColor: AppColors.rowHighlight,
            headerStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            nameStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            adhanStyle: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            iqamahStyle: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            order: const ['Fajr','Sunrise','Dhuhr','Asr','Maghrib','Isha',"Jummua'h"],
          )),
        ),
      ],
    );

    // Use a Scaffold to guarantee paint; keep your gradient.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(gradient: AppColors.pageGradient),
          child: content,
        ),
      ),
    );
  }
}