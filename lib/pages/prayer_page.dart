// lib/pages/prayer_page.dart
import 'dart:async';
//import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../utils/time_utils.dart';
import '../utils/clock_skew.dart';
import '../utils/countdown_format.dart' as cdf;
import '../widgets/top_header.dart';
import '../widgets/salah_table.dart';
import '../models.dart';
import '../app_colors.dart';
import '../main.dart' show AppGradients;
import '../localization/prayer_labels.dart';
import '../widgets/dst_pill_stealth.dart';
import 'dart:ui' show ImageFilter; // for ImageFilter.blur

// ─────────────────────────────────────────────────────────────────────────────
// LIGHT THEME CONSTANTS (unchanged)
const _kLightTextPrimary = Color(0xFF0F2432);
const _kLightTextMuted   = Color(0xFF4A6273);
const _kLightDivider     = Color(0xFF7B90A0);
const _kLightHighlight   = Color(0xFFFFF0C9);
const _kLightPanel       = Color(0xFFE9F2F9);
const _kLightPanelTop    = Color(0xFFDDEAF3);
const _kLightPanelBottom = Color(0xFFCBDCE8);
const _kLightGoldDigits  = Color(0xFF9C7C2C);

const double kTempFallbackF = 72.0;
const double _kHeaderHeight = 116.0;
const bool   enableDstPreviewToggle = false;

// EDIT THESE to change the countdown digit sizes (light & dark)
const double kCountdownDigitSizeLight = 56;
const double kCountdownDigitSizeDark  = 56;
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
  TextStyle? _hdrLight, _hdrDark, _nameLight, _nameDark, _valLight, _valDark;
  bool? _stylesForLight; // remembers which brightness the cached styles target

  // Ensures styles exist and match current brightness
  void _ensureStyles(bool isLight) {
    // If we already computed for this brightness, keep them
    if (_stylesForLight == isLight &&
        _hdrLight != null && _hdrDark != null &&
        _nameLight != null && _nameDark != null &&
        _valLight != null && _valDark != null) {
      return;
    }
    // Light styles (use your existing light constants/colors)
    _hdrLight  = const TextStyle(
        color: _kLightTextPrimary, fontSize: 16, fontWeight: FontWeight.w600);
    _nameLight = const TextStyle(
        color: _kLightTextPrimary, fontSize: 16, fontWeight: FontWeight.w500);
    _valLight  = const TextStyle(
        color: _kLightTextPrimary, fontSize: 16, fontWeight: FontWeight.w600);
    // Dark styles (use your existing AppColors for dark scheme)
    _hdrDark  = TextStyle(
        color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600);
    _nameDark = TextStyle(
        color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500);
    _valDark  = TextStyle(
        color: AppColors.textPrimary,   fontSize: 16, fontWeight: FontWeight.w600);
    _stylesForLight = isLight;
  }

  @override
  void initState() {
    super.initState();
    _initTracker();
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
      case 'fajr':     return 'Fajr';
      case 'sunrise':  return 'Sunrise';
      case 'dhuhr':    return 'Dhuhr';
      case 'asr':      return 'Asr';
      case 'maghrib':  return 'Maghrib';
      case 'isha':     return 'Isha';
      case "jummua'h":
      case "jummu'ah":
      case 'jummuah':
      case 'jumuah':   return "Jumu'ah";
      default:         return s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));
    }
  }

  // Parse "HH:mm" as TZDateTime on the mosque's zone for a given base date
  tz.TZDateTime? _mkTimeTz(tz.Location loc, DateTime base, String hhmm) {
    if (hhmm.isEmpty) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return tz.TZDateTime(loc, base.year, base.month, base.day, h, m);
  }

  Widget _guarded(Widget Function() build) {
    try { return build(); }
    catch (e, st) {
      debugPrint('PrayerPage child build error: $e\n$st');
      return Container(
        color: Colors.red.shade900,
        padding: const EdgeInsets.all(16),
        child: const Text('Error building widget.', style: TextStyle(color: Colors.white)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ag = Theme.of(context).extension<AppGradients>();
    final bgGradient = (ag != null) ? ag.page : AppColors.pageGradient;

    final next = _next;
    if (next == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    // Table text styles (unchanged)
    _ensureStyles(isLight);
    final headerTextStyle = isLight ? _hdrLight!  : _hdrDark!;
    final nameTextStyle   = isLight ? _nameLight! : _nameDark!;
    final valueTextStyle  = isLight ? _valLight!  : _valDark!;
    final bannerTitle = PrayerLabels.countdownHeader(context, next.name);

    // ── DST (live, zone‑aware) ────────────────────────────────────────────────
    final tz.TZDateTime nowTz = tz.TZDateTime.now(widget.location);
    final bool sysIsDst = () {
      // Compare today's offset to Jan 1 in same zone — flips naturally on DST days
      final jan1 = tz.TZDateTime(widget.location, nowTz.year, 1, 1);
      return nowTz.timeZoneOffset != jan1.timeZoneOffset;
    }();
    final bool effectiveIsDst = _dstPreview ?? sysIsDst;
    // ─────────────────────────────────────────────────────────────────────────

    // After today's Isha adhan begins, switch Fajr/Sunrise to "tomorrow"
    final DateTime base = DateTime(
        widget.today.date.year, widget.today.date.month, widget.today.date.day);
    final tz.TZDateTime? ishaAdhanTodayTz =
    _mkTimeTz(widget.location, base, widget.today.prayers['isha']?.begin ?? '');
    final bool afterIshaAdhan = (ishaAdhanTodayTz != null) && nowTz.isAfter(ishaAdhanTodayTz);

    final bool useTomorrowFajr    = afterIshaAdhan && widget.tomorrow != null;
    final bool useTomorrowSunrise = afterIshaAdhan && widget.tomorrow != null;

    // Build data maps (only Fajr/Sunrise conditionally switch to tomorrow)
    final adhanByName = <String, String>{
      'Fajr'   : useTomorrowFajr
          ? (widget.tomorrow!.prayers['fajr']?.begin ?? '')
          : (widget.today.prayers['fajr']?.begin ?? ''),
      'Sunrise': useTomorrowSunrise
          ? (widget.tomorrow!.sunrise ?? '')
          : (widget.today.sunrise ?? ''),
      'Dhuhr'  : widget.today.prayers['dhuhr']?.begin ?? '',
      'Asr'    : widget.today.prayers['asr']?.begin ?? '',
      'Maghrib': widget.today.prayers['maghrib']?.begin ?? '',
      'Isha'   : widget.today.prayers['isha']?.begin ?? '',
      "Jumu'ah": '13:30',
      if (effectiveIsDst) "Youth Jumu'ah": '16:00',
    };

    final iqamahByName = <String, String>{
      'Fajr'   : useTomorrowFajr
          ? (widget.tomorrow!.prayers['fajr']?.iqamah ?? '')
          : (widget.today.prayers['fajr']?.iqamah ?? ''),
      'Sunrise': '',
      'Dhuhr'  : widget.today.prayers['dhuhr']?.iqamah ?? '',
      'Asr'    : widget.today.prayers['asr']?.iqamah ?? '',
      'Maghrib': widget.today.prayers['maghrib']?.iqamah ?? '',
      'Isha'   : widget.today.prayers['isha']?.iqamah ?? '',
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
      // DST-aware now + drift correction:
      nowProvider: () => tz.TZDateTime.now(widget.location).add(ClockSkew.skew),
      onNextChanged: (newName) {
        if (_next?.name != newName && mounted) {
          setState(() { _next = _tracker.current; });
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
                  Icons.access_time_filled, size: 18,
                  color: effectiveIsDst ? const Color(0xFFC7A447)
                      : (isLight ? Colors.black : Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Daylight Saving Time',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: isLight ? _kLightTextPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
                Switch(
                  value: (_dstPreview != null) ? _dstPreview! : sysIsDst,
                  onChanged: (val) {
                    setState(() { _dstPreview = val ? true : false; });
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
                  },
                  activeThumbColor: const Color(0xFFC7A447),
                ),
              ],
            ),
          ),

        // Countdown
        countdownSection,

        // Salah Table
// ───────── Replace your whole Expanded(...) that wraps SalahTable with this ─────────
        Expanded(
          child: _guarded(
                () => RepaintBoundary(
              child: Stack(
                children: [
                  // UNDERLAY (light-only): keep previous look in light; disable in dark
                  if (isLight)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ClipRect(
                          child: ImageFiltered(
                            imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFFD6E6F1), Color(0xFFFFFFFF)],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // GLASS TABLE (edge-to-edge)
                  KeyedSubtree(
                    key: const ValueKey('salah_table_glass'),
                    child: SalahTable(
                      adhanByName: adhanByName,
                      iqamahByName: iqamahByName,
                      iqamahWidgetByName: iqamahWidgetByName,
                      highlightName: _titleCase(next.name),
                      expandRowsToFill: true,

                      // Rely on glass container surface
                      headerGreen: false,
                      headerBackgroundGradient: null,
                      headerBackgroundColor: Colors.transparent,
                      rowOddColor: Colors.transparent,
                      rowEvenColor: Colors.transparent,

                      highlightColor: AppColors.rowHighlight,
                      highlightColorLight: _kLightHighlight,
                      rowDividerColorLight: _kLightDivider.withValues(alpha: 0.25),
                      rowDividerThickness: 0.8,

                      headerStyle: headerTextStyle,
                      nameStyle: nameTextStyle,
                      adhanStyle: valueTextStyle,
                      iqamahStyle: valueTextStyle,
                      order: order,

                      // Keep glass surface ON, but tune only the DARK values
                      useGlassSurface: true,
                      glassBlur: 8,
                      glassTintLight: Colors.white.withValues(alpha: 0.70),
                      // ↓ Dark-only tweak to avoid washout while preserving glass feel
                      glassTintDark: const Color(0xFF0A1E3A).withValues(alpha: 0.28),
                      glassBorderLight: Colors.white.withValues(alpha: 0.85),
                      glassBorderDark: const Color(0xFFC7A447).withValues(alpha: 0.40),
                      glassBorderWidth: 1.0,
                      glassRadius: BorderRadius.zero, // edge-to-edge, no outer rounding
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
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
// CountdownBanner (human-friendly text: "H hours : M mins" or "S secs")
class CountdownBanner extends StatefulWidget {
  final NextPrayerTracker tracker;
  final bool isLight;
  final String title;
  final void Function(String newNextName)? onNextChanged;

  /// Optional: provide a "now" source (e.g., tz.TZDateTime.now(zone) + ClockSkew.skew).
  /// If null, falls back to DateTime.now().
  final DateTime Function()? nowProvider;

  const CountdownBanner({
    super.key,
    required this.tracker,
    required this.isLight,
    required this.title,
    this.onNextChanged,
    this.nowProvider,
  });

  // Keep your existing styles
  static const TextStyle kTitleLight = TextStyle(
    color: _kLightTextMuted, fontSize: 14, fontWeight: FontWeight.w600,
  );
  static const TextStyle kTitleDark = TextStyle(
    color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600,
  );
  static const TextStyle kDigitsLight = TextStyle(
    color: _kLightGoldDigits, fontSize: kCountdownDigitSizeLight,
    fontWeight: FontWeight.w700, letterSpacing: 1.0,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
  static const TextStyle kDigitsDark = TextStyle(
    color: AppColors.countdownText, fontSize: kCountdownDigitSizeDark,
    fontWeight: FontWeight.w700, letterSpacing: 1.0,
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

  bool get _shouldTick => _life == AppLifecycleState.resumed && _tickerModeEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tickOnce();
    _ensureTicker();
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
        _firstStart ? _startTickerAligned() : _startTickerImmediate();
      }
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }


  void _tickOnce() {
    // Use provided (DST-aware, drift-corrected) time if available; else fallback.
    final now = widget.nowProvider?.call() ?? DateTime.now();
    final rem = widget.tracker.tick(now);
    final safe = rem.isNegative ? Duration.zero : rem;
    final newText = cdf.formatCountdownStyled(safe);
    final name = widget.tracker.current.name;

    if (name != _lastNextName) {
      _lastNextName = name;
      widget.onNextChanged?.call(name);
    }
    if (newText != _digits) {
      if (!mounted) return;
      setState(() => _digits = newText);
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
    final title = widget.title;
    final cs = Theme.of(context).colorScheme; // for dark primaryContainer

    final light = Container(
      decoration: const BoxDecoration(
        color: _kLightPanel,
        border: Border(
          top: BorderSide(color: _kLightPanelTop, width: 1),
          bottom: BorderSide(color: _kLightPanelBottom, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          Text(title, style: CountdownBanner.kTitleLight),
          const SizedBox(height: 1),
          Text(_digits, textWidthBasis: TextWidthBasis.longestLine,
              style: CountdownBanner.kDigitsLight),
        ],
      ),
    );

    final dark = Container(
      // Return to deep-navy panel + add subtle hairlines
      decoration: const BoxDecoration(
        color: AppColors.bgPrimary, // ← coherent with your page navy
        border: Border(
          top: BorderSide(color: Color(0x14FFFFFF), width: 1),   // ~8% white
          bottom: BorderSide(color: Color(0x1AFFFFFF), width: 1),// ~10% white
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          Text(title, style: CountdownBanner.kTitleDark),
          const SizedBox(height: 1),
          Text(_digits,
              textWidthBasis: TextWidthBasis.longestLine,
              style: CountdownBanner.kDigitsDark),
        ],
      ),
    );

    return RepaintBoundary(child: isLight ? light : dark);
  }
}