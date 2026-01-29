// lib/pages/prayer_page.dart
import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../utils/time_utils.dart';
import '../widgets/top_header.dart';
import '../widgets/salah_table.dart';
import '../models.dart';
import '../app_colors.dart';
import '../main.dart' show AppGradients;
import '../localization/prayer_labels.dart';
import '../widgets/dst_pill_stealth.dart';
import '../warm_up.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LIGHT THEME CONSTANTS (unchanged)
const _kLightTextPrimary = Color(0xFF0F2432);
const _kLightTextMuted   = Color(0xFF4A6273);
const _kLightRowAlt      = Color(0xFFE5ECF2);
const _kLightCard        = Color(0xFFFFFFFF);
const _kLightDivider     = Color(0xFF7B90A0);
const _kLightHighlight   = Color(0xFFFFF0C9);
const _kLightPanel       = Color(0xFFE9F2F9);
const _kLightPanelTop    = Color(0xFFDDEAF3);
const _kLightPanelBottom = Color(0xFFCBDCE8);
const _kLightGoldDigits  = Color(0xFF9C7C2C);

const double kTempFallbackF = 72.0;
const double _kHeaderHeight = 116.0;
const bool enableDstPreviewToggle = false;

// ─────────────────────────────────────────────────────────────────────────────
// ✨ EDIT THESE to change the countdown digit sizes (light & dark)
const double kCountdownDigitSizeLight = 56; // default was 40
const double kCountdownDigitSizeDark  = 56; // default was 42
// ─────────────────────────────────────────────────────────────────────────────

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
  late NextPrayerTracker _tracker;
  NextPrayer? _next;
  bool? _dstPreview;

  @override
  void initState() {
    super.initState();
    _initTracker();

    // Post-frame warm-ups
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await warmUpAboveTheFold(context);
      } catch (_) {}
      try {
        final isLight = Theme.of(context).brightness == Brightness.light;
        await warmUpSalahRow(context, isLight: isLight);
      } catch (_) {}
    });
  }

  void _initTracker() {
    _tracker = NextPrayerTracker(
      loc: widget.location,
      nowLocal: DateTime.now(),
      today: widget.today,
      tomorrow: widget.tomorrow,
    );
    _next = _tracker.current;
  }

  @override
  void didUpdateWidget(covariant PrayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dayChanged =
        oldWidget.today.date != widget.today.date ||
            oldWidget.tomorrow?.date != widget.tomorrow?.date;
    final locChanged = oldWidget.location.name != widget.location.name;
    if (dayChanged || locChanged) {
      _initTracker();
      if (mounted) setState(() {});
    }
  }

  String _titleCase(String s) {
    final x = s.toLowerCase();
    switch (x) {
      case 'fajr':    return 'Fajr';
      case 'sunrise': return 'Sunrise';
      case 'dhuhr':   return 'Dhuhr';
      case 'asr':     return 'Asr';
      case 'maghrib': return 'Maghrib';
      case 'isha':    return 'Isha';
      case "jummua'h":
      case "jummu'ah":
      case 'jummuah':
      case 'jumuah':  return "Jumu'ah";
      default:        return s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));
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
    final bgGradient =
        Theme.of(context).extension<AppGradients>()?.page ??
            AppColors.pageGradient;

    final next = _next;
    if (next == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    // Table styles (unchanged)
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

    final bannerTitle = PrayerLabels.countdownHeader(context, next.name);

    // DST / schedule
    final bool sysIsDst = widget.location
        .timeZone(widget.nowLocal.millisecondsSinceEpoch)
        .isDst;
    final bool effectiveIsDst = _dstPreview ?? sysIsDst;

    // Build data maps
    final adhanByName = <String, String>{
      'Fajr'     : widget.today.prayers['fajr']?.begin     ?? '',
      'Sunrise'  : widget.today.sunrise                    ?? '',
      'Dhuhr'    : widget.today.prayers['dhuhr']?.begin    ?? '',
      'Asr'      : widget.today.prayers['asr']?.begin      ?? '',
      'Maghrib'  : widget.today.prayers['maghrib']?.begin  ?? '',
      'Isha'     : widget.today.prayers['isha']?.begin     ?? '',
      "Jumu'ah"  : '13:30',
      if (effectiveIsDst) "Youth Jumu'ah": '16:00',
    };

    final iqamahByName = <String, String>{
      'Fajr'     : widget.today.prayers['fajr']?.iqamah    ?? '',
      'Sunrise'  : '',
      'Dhuhr'    : widget.today.prayers['dhuhr']?.iqamah   ?? '',
      'Asr'      : widget.today.prayers['asr']?.iqamah     ?? '',
      'Maghrib'  : widget.today.prayers['maghrib']?.iqamah ?? '',
      'Isha'     : widget.today.prayers['isha']?.iqamah    ?? '',
      "Jumu'ah"  : '14:00',
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
                : (_dstPreview! ? false : null);
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
      'Fajr','Sunrise','Dhuhr','Asr','Maghrib','Isha',"Jumu'ah",
      if (effectiveIsDst) "Youth Jumu'ah",
    ];

    final countdownSection = CountdownBanner(
      tracker: _tracker,
      isLight: isLight,
      title: bannerTitle,
      onNextChanged: (newName) {
        if (_next?.name != newName && mounted) {
          setState(() {
            _next = _tracker.current;
          });
        }
      },
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _guarded(
              () => RepaintBoundary(
            child: SizedBox(
              height: _kHeaderHeight,
              child: TopHeader(
                location: widget.location,
                nowLocal: DateTime.now(),
                today: widget.today,
                tomorrow: widget.tomorrow,
                temperatureF: widget.temperatureF ?? kTempFallbackF,
              ),
            ),
          ),
        ),
        Container(height: 1, color: AppColors.goldDivider),

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
                      color: isLight ? _kLightTextPrimary : AppColors.textSecondary,
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
                  activeThumbColor: const Color(0xFFC7A447),
                ),
              ],
            ),
          ),

        // Countdown (isolated)
        countdownSection,

        // Salah Table (isolated)
        Expanded(
          child: _guarded(
                () => RepaintBoundary(
              child: KeyedSubtree(
                key: const ValueKey('salah_table_static'),
                child: SalahTable(
                  adhanByName: adhanByName,
                  iqamahByName: iqamahByName,
                  iqamahWidgetByName: iqamahWidgetByName,
                  highlightName: _titleCase(next.name),
                  expandRowsToFill: true,
                  headerGreen: false,
                  headerBackgroundGradient: isLight ? null : AppColors.headerGradient,
                  headerBackgroundColor: isLight ? Colors.white : null,
                  rowOddColor:  isLight ? _kLightCard : AppColors.bgSecondary,
                  rowEvenColor: isLight ? _kLightRowAlt : AppColors.bgSecondary,
                  highlightColor: AppColors.rowHighlight,
                  highlightColorLight: _kLightHighlight,
                  rowDividerColorLight: _kLightDivider.withValues(alpha: 0.16),
                  headerStyle: headerTextStyle,
                  nameStyle: nameTextStyle,
                  adhanStyle: valueTextStyle,
                  iqamahStyle: valueTextStyle,
                  order: order,
                ),
              ),
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
          child: RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(gradient: bgGradient),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CountdownBanner
//   • Lifecycle-aware + Tab-aware (TickerMode) pause
//   • Aligns first 1‑sec tick to the next wall‑second
//   • Uses tabular digits + textWidthBasis for stable layout
//   • ✨ Styles const‑hoisted; font size editable at the constants above
// ─────────────────────────────────────────────────────────────────────────────
class CountdownBanner extends StatefulWidget {
  final NextPrayerTracker tracker;
  final bool isLight;
  final String title;
  final void Function(String newNextName)? onNextChanged;

  const CountdownBanner({
    super.key,
    required this.tracker,
    required this.isLight,
    required this.title,
    this.onNextChanged,
  });

  // ── CONST‑HOISTED TEXT STYLES (use size constants at the top) ──────────────
  static const TextStyle kTitleLight = TextStyle(
    color: _kLightTextMuted,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle kTitleDark = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle kDigitsLight = TextStyle(
    color: _kLightGoldDigits,
    fontSize: kCountdownDigitSizeLight,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle kDigitsDark = TextStyle(
    color: AppColors.countdownText,
    fontSize: kCountdownDigitSizeDark,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.0,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  @override
  State<CountdownBanner> createState() => _CountdownBannerState();
}

class _CountdownBannerState extends State<CountdownBanner>
    with WidgetsBindingObserver {
  Timer? _ticker;
  String _digits = '--:--';
  String? _lastNextName;

  AppLifecycleState _life = AppLifecycleState.resumed;
  bool _tickerModeEnabled = true;
  bool _firstStart = true;

  bool get _shouldTick =>
      _life == AppLifecycleState.resumed && _tickerModeEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tickOnce();     // initialize display
    _ensureTicker(); // start aligned/immediate as needed
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _life = state;
    _ensureTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.of(context);
    if (enabled != _tickerModeEnabled) {
      _tickerModeEnabled = enabled;
      _ensureTicker();
    }
  }

  void _startTickerAligned() {
    final now = DateTime.now();
    final msToNextSecond = 1000 - now.millisecond;
    Timer(Duration(milliseconds: msToNextSecond), () {
      if (!mounted || !_shouldTick || _ticker != null) return;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tickOnce());
    });
    _firstStart = false;
  }

  void _startTickerImmediate() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tickOnce());
  }

  void _ensureTicker() {
    if (_shouldTick) {
      if (_ticker == null) {
        if (_firstStart) {
          _startTickerAligned();
        } else {
          _startTickerImmediate();
        }
      }
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _tickOnce() {
    final rem = widget.tracker.tick(DateTime.now());
    final safe = rem.isNegative ? Duration.zero : rem;
    final newDigits = formatCountdown(safe);
    final name = widget.tracker.current?.name ?? '';

    if (name != _lastNextName) {
      _lastNextName = name;
      widget.onNextChanged?.call(name);
    }

    if (newDigits != _digits) {
      if (!mounted) return;
      setState(() => _digits = newDigits);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = widget.isLight;
    final title   = widget.title;

    final light = Container(
      decoration: const BoxDecoration(
        color: _kLightPanel,
        border: Border(
          top:    BorderSide(color: _kLightPanelTop,    width: 1),
          bottom: BorderSide(color: _kLightPanelBottom, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 2), //previously 16
      child: Column(
        children: [
          Text(title, style: CountdownBanner.kTitleLight),
          const SizedBox(height: 1), //previously 6
          Text(
            _digits,
            textWidthBasis: TextWidthBasis.longestLine,
            style: CountdownBanner.kDigitsLight,
          ),
        ],
      ),
    );

    final dark = Container(
      color: AppColors.bgPrimary,
      padding: const EdgeInsets.symmetric(vertical: 2), //previously 12
      child: Column(
        children: [
          Text(title, style: CountdownBanner.kTitleDark),
          const SizedBox(height: 1), //previously 6
          Text(
            _digits,
            textWidthBasis: TextWidthBasis.longestLine,
            style: CountdownBanner.kDigitsDark,
          ),
        ],
      ),
    );

    return RepaintBoundary(child: isLight ? light : dark);
  }
}