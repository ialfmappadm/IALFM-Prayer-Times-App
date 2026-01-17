
// lib/pages/prayer_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../utils/time_utils.dart'; // NextPrayerTracker, formatCountdown, format12h
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

  // NEW: tracker + state that only changes when needed
  late NextPrayerTracker _tracker;
  Duration _remaining = Duration.zero;
  NextPrayer? _next;

  @override
  void initState() {
    super.initState();
    _initTrackerAndTicker();
  }

  void _initTrackerAndTicker() {
    // Initialize tracker once with current props
    _tracker = NextPrayerTracker(
      loc: widget.location,
      nowLocal: DateTime.now(),
      today: widget.today,
      tomorrow: widget.tomorrow,
    );

    _next = _tracker.current;
    _remaining = _tracker.tick(DateTime.now());

    // Start after first frame to avoid any pre-paint jank.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        final rem = _tracker.tick(DateTime.now());
        if (!mounted) return;
        setState(() {
          _remaining = rem;
          _next = _tracker.current; // flips only at boundary/day change
        });
      });
    });
  }

  @override
  void didUpdateWidget(covariant PrayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If 'today'/'tomorrow' or location change (midnight refresh or remote update),
    // re-initialize the tracker once rather than recomputing every second.
    final dayChanged =
        oldWidget.today.date != widget.today.date ||
            oldWidget.tomorrow?.date != widget.tomorrow?.date;

    final locChanged = oldWidget.location.name != widget.location.name;

    if (dayChanged || locChanged) {
      _initTrackerAndTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _titleCase(String s) {
    switch (s.toLowerCase()) {
      case 'fajr':
        return 'Fajr';
      case 'sunrise':
        return 'Sunrise';
      case 'dhuhr':
        return 'Dhuhr';
      case 'asr':
        return 'Asr';
      case 'maghrib':
        return 'Maghrib';
      case 'isha':
        return 'Isha';
      case "jummua'h":
        return "Jummua'h";
      case 'jumuah':
        return 'Jumuah';
      default:
        return s;
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
    // Use tracker-driven values; do not recompute next prayer here.
    final next = _next;
    final remaining = _remaining.isNegative ? Duration.zero : _remaining;

    // If tracker isn't ready yet (first frame), render a minimal placeholder.
    if (next == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final bannerTitle = '${_titleCase(next.name)} Adhan in…';

    // Keep your existing naming map (unchanged)
    final adhanByName = <String, String>{
      'Fajr': widget.today.prayers['fajr']?.begin ?? '',
      'Sunrise': widget.today.sunrise ?? '',
      'Dhuhr': widget.today.prayers['dhuhr']?.begin ?? '',
      'Asr': widget.today.prayers['asr']?.begin ?? '',
      'Maghrib': widget.today.prayers['maghrib']?.begin ?? '',
      'Isha': widget.today.prayers['isha']?.begin ?? '',
      "Jummua'h": '13:30', // static
    };

    final iqamahByName = <String, String>{
      'Fajr': widget.today.prayers['fajr']?.iqamah ?? '',
      'Sunrise': '', // no iqamah for sunrise
      'Dhuhr': widget.today.prayers['dhuhr']?.iqamah ?? '',
      'Asr': widget.today.prayers['asr']?.iqamah ?? '',
      'Maghrib': widget.today.prayers['maghrib']?.iqamah ?? '',
      'Isha': widget.today.prayers['isha']?.iqamah ?? '',
      "Jummua'h": '14:00', // static
    };

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _guarded(() => TopHeader(
          location: widget.location,
          nowLocal: DateTime.now(), // show live clock in header if it uses it
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
          child: _guarded(
                () => SalahTable(
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
              order: const ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha', "Jummua'h"],
            ),
          ),
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