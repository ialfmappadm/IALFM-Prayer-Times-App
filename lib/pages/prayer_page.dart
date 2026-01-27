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
// Localization helper
import '../localization/prayer_labels.dart';

// Stealth DST pill (your replacement for dst_badge.dart)
import '../widgets/dst_pill_stealth.dart';

// ---- Light Theme Constants ----
const _kLightTextPrimary = Color(0xFF0F2432);
const _kLightTextMuted = Color(0xFF4A6273);
const _kLightRowAlt = Color(0xFFE5ECF2);
const _kLightCard = Color(0xFFFFFFFF);
const _kLightDivider = Color(0xFF7B90A0);
const _kLightHighlight = Color(0xFFFFF0C9);

// Light countdown panel
const _kLightPanel = Color(0xFFE9F2F9);
const _kLightPanelTop = Color(0xFFDDEAF3);
const _kLightPanelBottom = Color(0xFFCBDCE8);
const _kLightGoldDigits = Color(0xFF9C7C2C);

const double kTempFallbackF = 72.0;

// Enable = show DST preview UI. Disable = production mode.
const bool enableDstPreviewToggle = false;

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

  /// null = Auto DST (system)
  /// true = force ON
  /// false = force OFF
  bool? _dstPreview;

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

    final dayChanged = oldWidget.today.date != widget.today.date ||
        oldWidget.tomorrow?.date != widget.tomorrow?.date;
    final locChanged = oldWidget.location.name != widget.location.name;

    if (dayChanged || locChanged) _initTrackerAndTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _titleCase(String s) {
    final x = s.toLowerCase();
    switch (x) {
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
      case "jummu'ah":
      case 'jummuah':
      case 'jumuah':
        return "Jumu'ah";
      default:
        return s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));
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
        child: const Text(
          'Error building widget.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    final bgGradient = Theme.of(context).extension<AppGradients>()?.page ??
        AppColors.pageGradient;

    final next = _next;
    final remaining = _remaining.isNegative ? Duration.zero : _remaining;

    if (next == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    // Table style
    final headerTextStyle = TextStyle(
      color: isLight ? _kLightTextPrimary : AppColors.textSecondary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );

    final nameTextStyle = TextStyle(
      color: isLight ? _kLightTextPrimary : AppColors.textSecondary,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );

    final valueTextStyle = TextStyle(
      color: isLight ? _kLightTextPrimary : AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );

    final bannerTitle = PrayerLabels.countdownHeader(context, next.name);

    // DST detection
    final bool sysIsDst = widget.location
        .timeZone(widget.nowLocal.millisecondsSinceEpoch)
        .isDst;

    final bool effectiveIsDst = _dstPreview ?? sysIsDst;

    //------------------ Build Prayer Maps --------------------
    final adhanByName = <String, String>{
      'Fajr': widget.today.prayers['fajr']?.begin ?? '',
      'Sunrise': widget.today.sunrise ?? '',
      'Dhuhr': widget.today.prayers['dhuhr']?.begin ?? '',
      'Asr': widget.today.prayers['asr']?.begin ?? '',
      'Maghrib': widget.today.prayers['maghrib']?.begin ?? '',
      'Isha': widget.today.prayers['isha']?.begin ?? '',
      "Jumu'ah": '13:30',
      if (effectiveIsDst) "Youth Jumu'ah": '16:00',
    };

    final iqamahByName = <String, String>{
      'Fajr': widget.today.prayers['fajr']?.iqamah ?? '',
      'Sunrise': '',
      'Dhuhr': widget.today.prayers['dhuhr']?.iqamah ?? '',
      'Asr': widget.today.prayers['asr']?.iqamah ?? '',
      'Maghrib': widget.today.prayers['maghrib']?.iqamah ?? '',
      'Isha': widget.today.prayers['isha']?.iqamah ?? '',
      "Jumu'ah": '14:00',
      if (effectiveIsDst) "Youth Jumu'ah": '16:15',
    };

    final iqamahWidgetByName = <String, Widget>{
      'Sunrise': GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enableDstPreviewToggle
            ? () {
          setState(() {
            _dstPreview = _dstPreview == null
                ? true
                : (_dstPreview == true ? false : null);
          });

          final mode = _dstPreview == null
              ? 'Auto (System)'
              : (_dstPreview! ? 'Forced ON (Preview)' : 'Forced OFF (Preview)');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('DST mode: $mode'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
            : null,
        child: DstPillStealth(
          isDst: effectiveIsDst,
          isLight: isLight,
        ),
      ),
    };

    final order = <String>[
      'Fajr',
      'Sunrise',
      'Dhuhr',
      'Asr',
      'Maghrib',
      'Isha',
      "Jumu'ah",
      if (effectiveIsDst) "Youth Jumu'ah",
    ];

    // Countdown UI
    final Widget countdownSection = isLight
        ? Container(
      decoration: BoxDecoration(
        color: _kLightPanel,
        border: Border(
          top: BorderSide(color: _kLightPanelTop, width: 1),
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

    // ---------------- PAGE CONTENT ----------------
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header
        _guarded(
              () => TopHeader(
            location: widget.location,
            nowLocal: DateTime.now(),
            today: widget.today,
            tomorrow: widget.tomorrow,
            temperatureF: widget.temperatureF ?? kTempFallbackF,
          ),
        ),

        // Gold divider
        Container(height: 1, color: AppColors.goldDivider),

        // ==========================
        // DST SWITCH ROW (requested)
        // ==========================
        if (enableDstPreviewToggle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_filled,
                  size: 18,
                  color: effectiveIsDst
                      ? const Color(0xFFC7A447)
                      : (isLight ? Colors.black : Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Daylight Saving Time',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color:
                      isLight ? _kLightTextPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
                Switch(
                  value: _dstPreview ?? sysIsDst,
                  onChanged: (val) {
                    setState(() {
                      _dstPreview = val ? true : false;
                    });

                    final mode = _dstPreview == null
                        ? 'Auto (System)'
                        : (_dstPreview!
                        ? 'Forced ON (Preview)'
                        : 'Forced OFF (Preview)');

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('DST mode: $mode'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  activeColor: const Color(0xFFC7A447),
                ),
              ],
            ),
          ),

        // Countdown
        countdownSection,

        // Salah Table
        Expanded(
          child: _guarded(
                () => SalahTable(
              adhanByName: adhanByName,
              iqamahByName: iqamahByName,
              iqamahWidgetByName: iqamahWidgetByName,
              highlightName: _titleCase(next.name),
              expandRowsToFill: true,

              // Header: white in Light, gradient in dark
              headerGreen: false,
              headerBackgroundGradient:
              isLight ? null : AppColors.headerGradient,
              headerBackgroundColor: isLight ? Colors.white : null,

              // Rows
              rowOddColor: isLight ? _kLightCard : AppColors.bgSecondary,
              rowEvenColor: isLight ? _kLightRowAlt : AppColors.bgSecondary,

              // Highlights
              highlightColor: AppColors.rowHighlight,
              highlightColorLight: _kLightHighlight,

              // Divider
              rowDividerColorLight: _kLightDivider.withValues(alpha: 0.16),

              // Styles
              headerStyle: headerTextStyle,
              nameStyle: nameTextStyle,
              adhanStyle: valueTextStyle,
              iqamahStyle: valueTextStyle,

              order: order,
            ),
          ),
        ),
      ],
    );

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