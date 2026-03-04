import 'dart:io';
import 'dart:ui' as ui;
//import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'; // for FilteringTextInputFormatter
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

// Gallery/Downloads helpers
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

// 🔤 snake_case getters (your project)
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';

import '../app_colors.dart';
import '../main.dart' show AppGradients;
import '../widgets/salah_table.dart';
import '../widgets/dst_pill_stealth.dart';
import '../widgets/iqamah_poster.dart'; // poster widget (handles “TBD”, youth in DST)
import '../models.dart';
import '../utils/time_utils.dart';
import '../ux_prefs.dart';
//import '../localization/prayer_labels.dart';

enum _LayoutKind { table, poster }

class SalahTableGeneratorPage extends StatefulWidget {
  const SalahTableGeneratorPage({super.key, this.logoTargetPx = 80});
  final double logoTargetPx;

  @override
  State<SalahTableGeneratorPage> createState() => _SalahTableGeneratorPageState();
}

class _SalahTableGeneratorPageState extends State<SalahTableGeneratorPage> {
  // Capture ONLY content (not overlays) to avoid flicker
  final GlobalKey _captureKey = GlobalKey();

  // ===== Headroom below your floating nav =====
  // Content starts after: safe-area top + this extra
  static const double _topOverlayExtra = 5.0; // adjust to your top nav’s visual height

  // Bottom breathing room inside captured image
  static const double _bottomVisualMargin = 0.0;

  // Space so the floating download button never overlaps TABLE rows (table-only)
  static const double _btnReserve = 12.0;

  // Poster should also end above the floating Download button
  static const double _posterReserve = 64.0; // knob: ensures poster doesn’t run under the button

  // ===== Download button vertical position (simple, signed knob) =====
  // bottom = bottomSafe + _downloadButtonOffsetPx
  // → Positive moves UP from safe area; Negative pushes DOWN (below safe area).
  static const double _downloadButtonOffsetPx = -30.0;

  // Accent for primary actions in sheets (matches your app)
  static const Color _gold = Color(0xFFC7A447); // used widely across your sheets  [1](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/more_page.dart)

  // Data
  tz.Location? _loc;
  DateTime _todayLocal = DateTime.now();
  DateTime _selected = DateTime.now();
  final Map<int, List<PrayerDay>> _cacheByYear = {};
  PrayerDay? _selectedDay;

  // UI
  _LayoutKind _layout = _LayoutKind.table;
  bool _isExporting = false;

  // ✅ Khateeb names (poster)
  String _khateebMain = 'TBD';
  String _khateebYouth = 'TBD';

  // ────────────────────────────────────────────────────────────────────────────
  // ONE source of truth for background (light & dark)
  // ────────────────────────────────────────────────────────────────────────────
  BoxDecoration _pageBg(BuildContext ctx) {
    final g = Theme.of(ctx).extension<AppGradients>()?.page;
    if (g != null) return BoxDecoration(gradient: g);
    // Fallback (if extension not present): subtle vertical dark gradient
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0A1E3A), Color(0xFF091221)],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final loc = await initCentralTime().catchError((_) => tz.getLocation('America/Chicago'));
    final now = tz.TZDateTime.now(loc).toLocal();
    await _loadYearIntoCache(loc, now.year);
    _applySelectedDate(now);
    if (!mounted) return;
    setState(() {
      _loc = loc;
      _todayLocal = now;
    });
  }

  Future<void> _loadYearIntoCache(tz.Location loc, int year) async {
    if (_cacheByYear.containsKey(year) && _cacheByYear[year]!.isNotEmpty) return;
    final days = await loadPrayerDays(year: year).catchError((_) => <PrayerDay>[]);
    _cacheByYear[year] = days;
  }

  void _applySelectedDate(DateTime newLocal) {
    final days = _cacheByYear[newLocal.year] ?? const <PrayerDay>[];
    PrayerDay? findByDate(List<PrayerDay> all, DateTime d) {
      for (final p in all) {
        if (p.date.year == d.year && p.date.month == d.month && p.date.day == d.day) return p;
      }
      return null;
    }
    setState(() {
      _selected = DateTime(newLocal.year, newLocal.month, newLocal.day);
      _selectedDay = findByDate(days, _selected);
    });
  }

  bool _isDstOn(DateTime dateLocal) {
    final loc = _loc;
    if (loc == null) return false;
    final d = tz.TZDateTime(loc, dateLocal.year, dateLocal.month, dateLocal.day);
    final jan1 = tz.TZDateTime(loc, dateLocal.year, 1, 1);
    return d.timeZoneOffset != jan1.timeZoneOffset;
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Time & data maps
  // ────────────────────────────────────────────────────────────────────────────
  String _to12h(String raw) {
    if (raw.isEmpty || !raw.contains(':')) return raw;
    final p = raw.split(':');
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return raw;
    final dt = DateTime(2000, 1, 1, h, m);
    final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h12:${m.toString().padLeft(2, '0')} $ampm';
  }

  Map<String, String> _adhanRaw(PrayerDay d) => {
    'Fajr': d.prayers['fajr']?.begin ?? '',
    'Sunrise': d.sunrise ?? '',
    'Dhuhr': d.prayers['dhuhr']?.begin ?? '',
    'Asr': d.prayers['asr']?.begin ?? '',
    'Maghrib': d.prayers['maghrib']?.begin ?? '',
    'Isha': d.prayers['isha']?.begin ?? '',
    "Jumu'ah": '13:30',
    if (_isDstOn(_selected)) "Youth Jumu'ah": '16:00',
  };

  Map<String, String> _iqamahRaw(PrayerDay d) => {
    'Fajr': d.prayers['fajr']?.iqamah ?? '',
    'Sunrise': '',
    'Dhuhr': d.prayers['dhuhr']?.iqamah ?? '',
    'Asr': d.prayers['asr']?.iqamah ?? '',
    'Maghrib': d.prayers['maghrib']?.iqamah ?? '',
    'Isha': d.prayers['isha']?.iqamah ?? '',
    "Jumu'ah": '14:00',
    if (_isDstOn(_selected)) "Youth Jumu'ah": '16:15',
  };

  List<String> _tableOrder(bool dst) => <String>[
    'Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha', "Jumu'ah", if (dst) "Youth Jumu'ah",
  ];

  Map<String, Widget> _sunriseIqamahWidget(bool isLight) => <String, Widget>{
    'Sunrise': DstPillStealth(isDst: _isDstOn(_selected), isLight: isLight),
  };

  // ────────────────────────────────────────────────────────────────────────────
  // Save helpers (Photos/Gallery) — SILENT by default (one toast from caller)
  // ────────────────────────────────────────────────────────────────────────────
  Future<bool> _saveToGalleryOrDownloads(
      Uint8List bytes,
      String fname, {
        bool showToast = false,
      }) async {
    final messenger = ScaffoldMessenger.of(context);
    if (Platform.isIOS) {
      var addOnly = await Permission.photosAddOnly.status;
      var photos = await Permission.photos.status;

      bool hasWrite = addOnly.isGranted || photos.isGranted || photos.isLimited;
      if (!hasWrite) {
        addOnly = await Permission.photosAddOnly.request();
        hasWrite = addOnly.isGranted;
      }
      if (!hasWrite) {
        photos = await Permission.photos.request();
        hasWrite = photos.isGranted || photos.isLimited;
      }
      if (!hasWrite) {
        throw 'Photos permission denied (addOnly: ${addOnly.name}, full: ${photos.name})';
      }

      final res = await ImageGallerySaverPlus.saveImage(bytes, name: fname, quality: 100);
      assert(() {
        debugPrint('Gallery save (iOS): $res');
        return true;
      }());
      if (showToast && mounted) messenger.showSnackBar(const SnackBar(content: Text('Saved to Photos')));
      return true;
    }

    final res = await ImageGallerySaverPlus.saveImage(bytes, name: fname, quality: 100);
    assert(() {
      debugPrint('Gallery save (Android): $res');
      return true;
    }());
    if (showToast && mounted) messenger.showSnackBar(const SnackBar(content: Text('Saved to Photos/Gallery')));
    return true;
  }

  // Seamless export: overlays are outside capture; no setState during export.
  Future<void> _exportPng() async {
    if (_isExporting) return;
    _isExporting = true;

    final media = MediaQuery.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;

      final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // ✅ remove unnecessary cast; clamp returns num → convert safely to double
      final double dpr = media.devicePixelRatio.clamp(2.0, 3.0).toDouble();
      final ui.Image image = await boundary.toImage(pixelRatio: dpr);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final String mode = _layout == _LayoutKind.poster ? 'poster' : 'salah';
      final String date = DateFormat('yyyy-MM-dd').format(_selected);
      final String time = DateFormat('HHmmss_SSS').format(DateTime.now());
      final String fname = 'ialfm_${mode}_${date}_$time';

      await _saveToGalleryOrDownloads(bytes, fname, showToast: false);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Screenshot saved')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      _isExporting = false;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Bottom-sheet editor for Khateeb names (poster only)
  // Matches your sheet patterns (background, onSurface text, drag handle, buttons)
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _openKhateebSheet() async {
    if (_layout != _LayoutKind.poster) return;

    final theme = Theme.of(context);
    final bg = theme.bottomSheetTheme.backgroundColor;
  //  final cs = theme.colorScheme;
    final dstOn = _isDstOn(_selected);

    final ctrlMain  = TextEditingController(text: _khateebMain  == 'TBD' ? '' : _khateebMain);
    final ctrlYouth = TextEditingController(text: _khateebYouth == 'TBD' ? '' : _khateebYouth);
    final nameFilter = FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z \-]"));

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true, // lift with keyboard
      backgroundColor: bg,
      builder: (ctx) {
        final cs2 = Theme.of(ctx).colorScheme; // read from sheet context
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 8,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Khateeb Names',
                  style: TextStyle(color: cs2.onSurface, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Main Khateeb
                TextField(
                  controller: ctrlMain,
                  inputFormatters: [nameFilter],
                  textCapitalization: TextCapitalization.words,
                  cursorColor: cs2.primary,
                  style: TextStyle(color: cs2.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Main Khateeb',
                    labelStyle: TextStyle(color: cs2.onSurface.withValues(alpha: 0.90)),
                    hintText: 'Imam Rasheed Farah',
                    hintStyle: TextStyle(color: cs2.onSurface.withValues(alpha: 0.55)),
                    filled: true,
                    fillColor: cs2.surface.withValues(alpha: 0.06),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs2.outline.withValues(alpha: 0.30)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs2.primary),
                    ),
                  ),
                ),

                if (dstOn) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrlYouth,
                    inputFormatters: [nameFilter],
                    textCapitalization: TextCapitalization.words,
                    cursorColor: cs2.primary,
                    style: TextStyle(color: cs2.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Youth Khateeb',
                      labelStyle: TextStyle(color: cs2.onSurface.withValues(alpha: 0.90)),
                      hintText: 'Imam Rasheed Farah',
                      hintStyle: TextStyle(color: cs2.onSurface.withValues(alpha: 0.55)),
                      filled: true,
                      fillColor: cs2.surface.withValues(alpha: 0.06),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs2.outline.withValues(alpha: 0.30)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs2.primary),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(AppLocalizations.of(ctx).btn_cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _gold, foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          final m = ctrlMain.text.trim();
                          final y = ctrlYouth.text.trim();
                          setState(() {
                            _khateebMain = m.isEmpty ? 'TBD' : m;
                            if (dstOn) _khateebYouth = y.isEmpty ? 'TBD' : y;
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(AppLocalizations.of(ctx).btn_save),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Header (no arch) — date centered BETWEEN calendar & poster toggle
  // ────────────────────────────────────────────────────────────────────────────
  Widget _generatorHeader(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isLight = theme.brightness == Brightness.light;
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final clamped = media.textScaler.clamp(maxScaleFactor: 1.08);

    final titleSize = (w >= 430) ? 20.0 : (w >= 380 ? 18.0 : 16.0);
    final dateSize  = titleSize;
    final sideLaneW = (w < 360) ? 48.0 : (w < 400 ? 52.0 : 56.0);
    final double logoH = (w * 0.16).clamp(56.0, 92.0).toDouble();

    final greg = DateFormat('EEE, MMM d yyyy').format(_selected);
    final DateTime hijriAdjusted = _selected.add(Duration(days: UXPrefs.hijriEffectiveOffset));
    final hCal = HijriCalendar.fromDate(hijriAdjusted);
    const hijriMonths = [
      'Muharram','Safar','Rabi-al-Awwal','Rabi-al-Thani',
      'Jumada-al-awwal','Jumada-al-Thani','Rajab','Shaban',
      'Ramadan','Shawwal','Dhul-Qadah','Dhul-Hijjah',
    ];
    final hName = (hCal.hMonth >= 1 && hCal.hMonth <= 12) ? hijriMonths[hCal.hMonth - 1] : 'Hijri';
    final hijriStr = '$hName ${hCal.hDay}, ${hCal.hYear}';

    final headerDecoration = _pageBg(context);

    final title = Text(
      'Islamic Association of Lewisville - Flower Mound',
      maxLines: 1, softWrap: false, overflow: TextOverflow.visible, textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium?.copyWith(
        color: isLight ? const Color(0xFF0F2432) : AppColors.textSecondary,
        fontWeight: FontWeight.w700, fontSize: titleSize, letterSpacing: 0.2,
      ) ?? TextStyle(
        color: isLight ? const Color(0xFF0F2432) : AppColors.textSecondary,
        fontWeight: FontWeight.w700, fontSize: titleSize, letterSpacing: 0.2,
      ),
    );

    final dates = Text(
      '$greg • $hijriStr',
      maxLines: 1, softWrap: false, overflow: TextOverflow.visible, textAlign: TextAlign.center,
      style: theme.textTheme.titleMedium?.copyWith(
        color: isLight ? const Color(0xFF0F2432) : AppColors.textPrimary,
        fontWeight: FontWeight.w700, fontSize: dateSize, letterSpacing: 0.15,
      ) ?? TextStyle(
        color: isLight ? const Color(0xFF0F2432) : AppColors.textPrimary,
        fontWeight: FontWeight.w700, fontSize: dateSize, letterSpacing: 0.15,
      ),
    );

    return MediaQuery(
      data: media.copyWith(textScaler: clamped),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: headerDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: logoH,
                  child: Center(
                    child: GestureDetector(
                      onLongPress: _openKhateebSheet, // ✅ bottom-sheet editor (poster only)
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Image.asset('assets/branding/ialfm_logo_trimmed.png', height: logoH),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(fit: BoxFit.scaleDown, child: title),
                const SizedBox(height: 8),

                // Single row: calendar (left), date centered, poster toggle (right)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: sideLaneW,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: l10n.tip_pick_date,
                          onPressed: _openDateSheet,
                          padding: EdgeInsets.zero,
                          icon: const FaIcon(FontAwesomeIcons.calendarDays, size: 18),
                        ),
                      ),
                    ),
                    Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: dates))),
                    SizedBox(
                      width: sideLaneW,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: _layout == _LayoutKind.poster ? l10n.tip_poster_on : l10n.tip_poster_off,
                          onPressed: () => setState(() {
                            _layout = _layout == _LayoutKind.poster ? _LayoutKind.table : _LayoutKind.poster;
                          }),
                          padding: EdgeInsets.zero,
                          icon: FaIcon(
                            FontAwesomeIcons.newspaper,
                            size: 18,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.goldDivider),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Date picker
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _openDateSheet() async {
    final int year = _todayLocal.year;
    final DateTime minDate = DateTime(year, 1, 1);
    final DateTime maxDate = DateTime(year, 12, 31);

    DateTime initial = _selected;
    if (initial.isBefore(minDate)) initial = minDate;
    if (initial.isAfter(maxDate)) initial = maxDate;

    final l10n = AppLocalizations.of(context);

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return CupertinoTheme(
          data: CupertinoTheme.of(ctx).copyWith(
            primaryColor: const Color(0xFF4A6273),
            textTheme: const CupertinoTextThemeData(dateTimePickerTextStyle: TextStyle(fontSize: 20)),
          ),
          child: SafeArea(
            top: false,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              height: 264,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: initial, minimumDate: minDate, maximumDate: maxDate,
                      onDateTimeChanged: (value) {
                        final clamped = value.isBefore(minDate)
                            ? minDate : (value.isAfter(maxDate) ? maxDate : value);
                        _applySelectedDate(clamped);
                      },
                    ),
                  ),
                  Positioned(
                    right: 8, top: 8,
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(44, 32),
                      child: Text(l10n.btn_save, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Build — gradient background + (capture area) + overlays outside
  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final day = _selectedDay;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final headerTextStyle = isLight
        ? const TextStyle(color: Color(0xFF0F2432), fontSize: 16, fontWeight: FontWeight.w700)
        : TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w700);
    final nameTextStyle = isLight
        ? const TextStyle(color: Color(0xFF0F2432), fontSize: 16, fontWeight: FontWeight.w600)
        : TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600);
    final valueTextStyle = isLight
        ? const TextStyle(color: Color(0xFF0F2432), fontSize: 16, fontWeight: FontWeight.w700)
        : TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700);

    final media = MediaQuery.of(context);
    final bottomSafe = media.viewPadding.bottom;
    final topSafe = media.viewPadding.top;

    // Dynamic headroom below top nav: safe-area top + extra knob
    final double dynamicTopHeadroom = topSafe + _topOverlayExtra;

    return Scaffold(
      appBar: null,
      body: SafeArea(
        top: true,
        child: Stack(
          children: [
            // Background gradient under everything
            Container(decoration: _pageBg(context)),

            // Capture area only (no overlays)
            RepaintBoundary(
              key: _captureKey,
              child: Container(
                decoration: _pageBg(context),
                child: Column(
                  children: [
                    SizedBox(height: dynamicTopHeadroom),
                    _generatorHeader(context),

                    // CONTENT: Expanded to fill all remaining height
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          // Reserve space for the floating button ONLY for TABLE
                          bottom: _layout == _LayoutKind.table
                              ? _btnReserve + bottomSafe
                              : _posterReserve,
                        ),
                        child: day == null
                            ? Center(
                          child: Text(
                            l10n.msg_no_schedule,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        )
                            : (_layout == _LayoutKind.table)
                            ? KeyedSubtree(
                          key: const ValueKey('salah_table_glass_generator'),
                          child: SalahTable(
                            adhanByName: _adhanRaw(day),
                            iqamahByName: _iqamahRaw(day),
                            iqamahWidgetByName: _sunriseIqamahWidget(isLight),
                            highlightName: '__none__',
                            expandRowsToFill: true, // fill height

                            headerGreen: false,
                            headerBackgroundGradient: null,
                            headerBackgroundColor: Colors.transparent,

                            // Full-width + no gold border
                            rowOddColor: Colors.transparent,
                            rowEvenColor: Colors.transparent,
                            highlightColor: AppColors.rowHighlight,
                            highlightColorLight: const Color(0xFFFFF0C9),
                            rowDividerColorLight:
                            const Color(0xFF7B90A0).withValues(alpha: 0.25),
                            rowDividerThickness: 0.8,

                            // Consistent fonts for both columns
                            headerStyle: headerTextStyle,
                            nameStyle: nameTextStyle,
                            adhanStyle: valueTextStyle,
                            iqamahStyle: valueTextStyle,

                            order: _tableOrder(_isDstOn(_selected)),
                            useGlassSurface: true,
                            glassBlur: 8,
                            glassTintLight: Colors.white.withValues(alpha: 0.70),
                            glassTintDark: const Color(0xFF0A1E3A).withValues(alpha: 0.28),
                            glassBorderLight: Colors.transparent,
                            glassBorderDark: Colors.transparent,
                            glassBorderWidth: 0.0,
                            glassRadius: BorderRadius.zero,
                          ),
                        )
                            : _PosterFullHeight(
                          builder: (context, size) {
                            // ✅ Top-aligned scaleDown so poster never overflows on DST
                            return Align(
                              alignment: Alignment.topCenter,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: size.width,
                                    maxWidth: size.width,
                                  ),
                                  child: IqamahPoster(
                                    day: day,
                                    isLight: isLight,
                                    dstOn: _isDstOn(_selected),
                                    to12h: _to12h,
                                    l10n: l10n,
                                    maghribText: l10n.text_sunset_plus_5,
                                    adhanMap: _adhanRaw(day),
                                    iqamahMap: _iqamahRaw(day),
                                    firstKhateeb: _khateebMain,
                                    youthKhateeb: _khateebYouth,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: _bottomVisualMargin),
                  ],
                ),
              ),
            ),

            // Overlays (outside capture) — back & download
            Positioned(
              left: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.maybePop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: isLight ? const Color(0xFF0F2432) : Colors.white,
                  padding: const EdgeInsets.all(10),
                  shape: const CircleBorder(),
                  splashFactory: NoSplash.splashFactory,
                ),
              ),
            ),
            Positioned(
              right: 10,
              // >>> SIMPLE KNOB: bottomSafe + offset (offset may be negative to push further down)
              bottom: bottomSafe + _downloadButtonOffsetPx,
              child: IconButton(
                onPressed: _selectedDay == null || _isExporting ? null : _exportPng,
                icon: const Icon(Icons.download, size: 26),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: isLight ? const Color(0xFF0F2432) : Colors.white,
                  padding: const EdgeInsets.all(12),
                  shape: const CircleBorder(),
                  splashFactory: NoSplash.splashFactory,
                ),
                tooltip: l10n.tip_download,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper: sizes the child to available area
class _PosterFullHeight extends StatelessWidget {
  const _PosterFullHeight({required this.builder});
  final Widget Function(BuildContext context, Size size) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) => SizedBox(
        width: c.maxWidth,
        height: c.maxHeight,
        child: builder(ctx, Size(c.maxWidth, c.maxHeight)),
      ),
    );
  }
}