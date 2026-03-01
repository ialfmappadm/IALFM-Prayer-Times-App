import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/timezone.dart' as tz;

// 🔤 snake_case getters (your project)
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';

import '../app_colors.dart';
import '../main.dart' show AppGradients;
import '../widgets/salah_table.dart';
import '../widgets/dst_pill_stealth.dart';
import '../models.dart';
import '../utils/time_utils.dart';
import '../ux_prefs.dart';

// Use your existing EN/AR prayer-name helper (so we didn’t add new ARB keys here)
import '../localization/prayer_labels.dart'; // ← reuses names for Fajr/Dhuhr/…  [2](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/prayer_labels.dart)

enum _LayoutKind { table, poster }

class SalahTableGeneratorPage extends StatefulWidget {
  const SalahTableGeneratorPage({super.key, this.logoTargetPx = 80});
  final double logoTargetPx;

  @override
  State<SalahTableGeneratorPage> createState() => _SalahTableGeneratorPageState();
}

class _SalahTableGeneratorPageState extends State<SalahTableGeneratorPage> {
  final GlobalKey _captureKey = GlobalKey();

  // Data
  tz.Location? _loc;
  DateTime _todayLocal = DateTime.now();
  DateTime _selected = DateTime.now();
  final Map<int, List<PrayerDay>> _cacheByYear = {};
  PrayerDay? _selectedDay;

  // UI
  _LayoutKind _layout = _LayoutKind.table;
  bool _hideChrome = false;   // hides overlay icons during export
  bool _isExporting = false;  // prevents double‑tap overwrite
  String _firstKhateeb = 'TBD';
  String _youthKhateeb = 'TBD';

  // Visual constants
  static const double _gapHeader = 12.0;
  static const double _btnInset  = 6.0;
  static const double _btnReserve = 58.0; // bottom space for Download button

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
    'Fajr','Sunrise','Dhuhr','Asr','Maghrib','Isha',"Jumu'ah", if (dst) "Youth Jumu'ah",
  ];

  Map<String, Widget> _sunriseIqamahWidget(bool isLight) => <String, Widget>{
    'Sunrise': DstPillStealth(isDst: _isDstOn(_selected), isLight: isLight),
  };

  // ────────────────────────────────────────────────────────────────────────────
  // Export (unique filename; captures gradient; no white wash)
  // ────────────────────────────────────────────────────────────────────────────
  Future<File> _renderPng({double? pixelRatio}) async {
    final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final pr = pixelRatio ?? View.of(context).devicePixelRatio;
    final ui.Image image = await boundary.toImage(pixelRatio: pr);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final dir = await getApplicationDocumentsDirectory();
    final String mode = _layout == _LayoutKind.poster ? 'poster' : 'salah';
    final now = DateTime.now();
    final String date = DateFormat('yyyy-MM-dd').format(_selected);
    final String time = DateFormat('HHmmss_SSS').format(now); // include ms for uniqueness
    final String fname = 'ialfm_${mode}_${date}_$time.png';

    final file = await File('${dir.path}/$fname').create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _exportPng() async {
    if (_isExporting) return;
    _isExporting = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      setState(() => _hideChrome = true);
      await WidgetsBinding.instance.endOfFrame;
      await _renderPng(pixelRatio: null);
      messenger.showSnackBar(const SnackBar(content: Text('Screenshot saved successfully')));
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('An error occurred while saving')));
    } finally {
      if (mounted) setState(() => _hideChrome = false);
      _isExporting = false;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Poster editor (Khateeb)
  // ────────────────────────────────────────────────────────────────────────────
  Future<void> _editKhateebs(bool dst) async {
    final firstCtrl = TextEditingController(text: _firstKhateeb == 'TBD' ? '' : _firstKhateeb);
    final youthCtrl = TextEditingController(text: _youthKhateeb == 'TBD' ? '' : _youthKhateeb);
    bool firstUnknown = _firstKhateeb == 'TBD';
    bool youthUnknown = _youthKhateeb == 'TBD';

    final nameFmt = FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z \-]"));

    final result = await showModalBottomSheet<_KhateebResult>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      builder: (ctx) {
        const gold = Color(0xFFC7A447);
        final cs = Theme.of(ctx).colorScheme;
        final l10n = AppLocalizations.of(ctx);

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.sheet_khateeb_title, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _FieldWithUnknown(
                label: l10n.label_first_khateeb, // “Khateeb Name”
                controller: firstCtrl,
                unknown: firstUnknown,
                onUnknownChanged: (v) => firstUnknown = v,
                formatter: nameFmt,
              ),
              const SizedBox(height: 12),
              if (_isDstOn(_selected))
                _FieldWithUnknown(
                  label: l10n.label_youth_khateeb, // “Khateeb Name (Youth)”
                  controller: youthCtrl,
                  unknown: youthUnknown,
                  onUnknownChanged: (v) => youthUnknown = v,
                  formatter: nameFmt,
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: Text(l10n.btn_cancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: Colors.black,
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: () {
                        String f = firstCtrl.text.trim();
                        String y = youthCtrl.text.trim();
                        if (firstUnknown || f.isEmpty) f = 'TBD';
                        if (_isDstOn(_selected) && (youthUnknown || y.isEmpty)) y = 'TBD';
                        Navigator.pop(ctx, _KhateebResult(first: f, youth: y));
                      },
                      child: Text(l10n.btn_save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _firstKhateeb = result.first;
        _youthKhateeb = result.youth.isEmpty ? _youthKhateeb : result.youth;
      });
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Header (logo + date strip) — not an AppBar
  // ────────────────────────────────────────────────────────────────────────────
  Widget _generatorHeader(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isLight = theme.brightness == Brightness.light;
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final clamped = media.textScaler.clamp(maxScaleFactor: 1.10);

    final titleSize = (w >= 430) ? 20.0 : (w >= 380 ? 18.0 : 16.0);
    final dateBase  = (w >= 430) ? 22.0 : (w >= 380 ? 20.0 : 18.0);
    final dateSize  = (dateBase > titleSize) ? titleSize : dateBase;
    final sideLaneW = (w < 360) ? 48.0 : (w < 400 ? 52.0 : 56.0);

    // Smaller logo so it never hits the notch + leaves room for the overlay arrow
    final double logoH = (w * 0.18).clamp(64.0, 102.0).toDouble();

    // Dates (Gregorian + Hijri)
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

    final headerDecoration = isLight
        ? const BoxDecoration(color: Colors.white)
        : const BoxDecoration(gradient: AppColors.headerGradient);

    final title = Text(
      'Islamic Association of Lewisville - Flower Mound',
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      textAlign: TextAlign.center,
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
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      textAlign: TextAlign.center,
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: headerDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Long‑press logo in Poster mode to edit khateeb names
                GestureDetector(
                  onLongPress: _layout == _LayoutKind.poster ? () => _editKhateebs(_isDstOn(_selected)) : null,
                  child: SizedBox(
                    height: logoH,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Image.asset('assets/branding/ialfm_logo_trimmed.png', height: logoH),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _gapHeader),
                FittedBox(fit: BoxFit.scaleDown, child: title),
                const SizedBox(height: _gapHeader),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // LEFT: date picker (hidden during export)
                    SizedBox(
                      width: sideLaneW,
                      child: _hideChrome
                          ? const SizedBox.shrink()
                          : Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: l10n.tip_pick_date,
                          onPressed: _openDateSheet,
                          padding: EdgeInsets.zero,
                          icon: const FaIcon(FontAwesomeIcons.calendarDays, size: 18),
                        ),
                      ),
                    ),
                    // CENTER: dates
                    Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: dates))),
                    // RIGHT: poster toggle (hidden during export)
                    SizedBox(
                      width: sideLaneW,
                      child: _hideChrome
                          ? const SizedBox.shrink()
                          : Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: _layout == _LayoutKind.poster ? l10n.tip_poster_on : l10n.tip_poster_off,
                          onPressed: () => setState(
                                () => _layout = (_layout == _LayoutKind.poster) ? _LayoutKind.table : _LayoutKind.poster,
                          ),
                          padding: EdgeInsets.zero,
                          icon: FaIcon(
                            FontAwesomeIcons.newspaper, size: 18,
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
  // Poster (Iqamah) panel — matches Salah table colors; grouped Jumu'ah layout
  // ────────────────────────────────────────────────────────────────────────────
  Widget _posterPanel(
      PrayerDay day,
      BoxConstraints c, {
        required bool fillHeight,
        required bool exportMode,
      }) {
    // ── Localizations in-scope for this method ──────────────────────────
    final l10n = AppLocalizations.of(context);
    final jumuahTitle = PrayerLabels.prayerName(context, "Jumu'ah");
    final youthJumuahTitle = PrayerLabels.prayerName(context, "Youth Jumu'ah");

    final isLight = Theme.of(context).brightness == Brightness.light;

    // Match SalahTable glass surface
    final Color glassTint   = isLight ? Colors.white.withValues(alpha: 0.70)
        : const Color(0xFF0A1E3A).withValues(alpha: 0.28);
    final Color glassBorder = isLight ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFFC7A447).withValues(alpha: 0.40);

    // Headings slightly larger (but not overpowering)
    final headerStyle = TextStyle(
      color: isLight ? const Color(0xFF0F2432) : AppColors.textSecondary,
      fontSize: 18, fontWeight: FontWeight.w800,
    );
    final sectionStyle = TextStyle(
      color: isLight ? const Color(0xFF0F2432) : AppColors.textSecondary,
      fontSize: 16.5, fontWeight: FontWeight.w600, letterSpacing: 0.2,
    );

    // Salah names bold; times bold (per your UX choice)
    final nameStyle = TextStyle(
      color: isLight ? const Color(0xFF0F2432) : AppColors.textSecondary,
      fontSize: 16, fontWeight: FontWeight.w700,
    );
    final valueStyle = TextStyle(
      color: isLight ? const Color(0xFF0F2432) : AppColors.textPrimary,
      fontSize: 16, fontWeight: FontWeight.w700,
    );
    final subNameStyle = nameStyle.copyWith(
      fontSize: 15.0, fontWeight: FontWeight.w600,
      color: (isLight ? const Color(0xFF0F2432) : AppColors.textSecondary).withValues(alpha: 0.92),
    );

    // Compact a bit when Youth block is present → fit without scroll
    final bool compact = _isDstOn(_selected);
    final double rowVPad    = compact ? 10 : 12;
    final double subRowVPad = compact ? 8  : 10;
    final double sectionTopPad = compact ? 8 : 10;
    final double sectionBotPad = compact ? 4 : 6;

    String t(String? s) => (s == null || s.isEmpty) ? '—' : _to12h(s);

    // Main iqamah times
    final fajr   = t(day.prayers['fajr']?.iqamah);
    final dhuhr  = t(day.prayers['dhuhr']?.iqamah);
    final asr    = t(day.prayers['asr']?.iqamah);
    final maghrib = l10n.text_sunset_plus_5; // ← localized “Sunset + 5 mins”
    final isha   = t(day.prayers['isha']?.iqamah);

    // Map your stored Jumu'ah times to labels you requested:
    // Khutbah = 1:30 (adhan map), Iqamah = 2:00 (iqamah map)
    final adhanMap  = _adhanRaw(day);
    final iqamahMap = _iqamahRaw(day);
    final mainKhutbah = _to12h(adhanMap["Jumu'ah"] ?? '13:30');
    final mainIqamah  = _to12h(iqamahMap["Jumu'ah"] ?? '14:00');

    final dst = _isDstOn(_selected);
    final youthKhutbah = dst ? _to12h(adhanMap["Youth Jumu'ah"] ?? '16:00') : '';
    final youthIqamah  = dst ? _to12h(iqamahMap["Youth Jumu'ah"] ?? '16:15') : '';

    Widget divider([double alpha = 0.25]) => Divider(
      height: 0, thickness: 0.8,
      color: isLight ? const Color(0xFF7B90A0).withValues(alpha: alpha)
          : Colors.white.withValues(alpha: 0.10),
    );

    // Panel header
    Widget header() => Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: rowVPad),
      child: Center(
        child: Text(l10n.label_iqamah_times, // ← localized “Iqamah Times”
            style: headerStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );

    // Regular rows (name on left, time on right)
    Widget row(String left, String right) => Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: rowVPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(left, style: nameStyle, maxLines: 2, softWrap: true, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(right, style: valueStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );

    // Sub‑rows for Jumu‘ah / Youth (Khutbah / Iqamah)
    Widget subRow(String left, String right) => Padding(
      padding: EdgeInsets.fromLTRB(28, subRowVPad, 16, subRowVPad),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(left, style: subNameStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(right, style: valueStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );

    // Section headings (Jumu'ah / Youth Jumu'ah)
    Widget sectionHeading(String title) => Padding(
      padding: EdgeInsets.fromLTRB(16, sectionTopPad, 16, sectionBotPad),
      child: Text(title, style: sectionStyle),
    );

    // Glass-styled panel (same look as SalahTable)
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: glassTint,
        border: Border.all(color: glassBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header(),
          divider(),

          // Regular prayers (names via helper → localized automatically)
          row(PrayerLabels.prayerName(context, 'Fajr'),    fajr),    divider(),
          row(PrayerLabels.prayerName(context, 'Dhuhr'),   dhuhr),   divider(),
          row(PrayerLabels.prayerName(context, 'Asr'),     asr),     divider(),
          row(PrayerLabels.prayerName(context, 'Maghrib'), maghrib), divider(),
          row(PrayerLabels.prayerName(context, 'Isha'),    isha),    divider(),

          // Jumu‘ah group
          sectionHeading(jumuahTitle),
          subRow(l10n.label_khutbah, mainKhutbah), // ← localized “Khutbah”
          divider(0.18),
          subRow(l10n.label_iqamah,  mainIqamah),  // ← localized “Iqamah”
          divider(),

          // Khateeb (main) — localized label + localized TBD fallback
          row(l10n.label_first_khateeb,
              _firstKhateeb.trim().isEmpty ? l10n.label_unknown_tbd : _firstKhateeb.trim()),
          divider(),

          // Youth group (DST only)
          if (dst) ...[
            sectionHeading(youthJumuahTitle),
            subRow(l10n.label_khutbah, youthKhutbah),
            divider(0.18),
            subRow(l10n.label_iqamah,  youthIqamah),
            divider(),
            row(l10n.label_youth_khateeb,
                _youthKhateeb.trim().isEmpty ? l10n.label_unknown_tbd : _youthKhateeb.trim()),
            divider(),
          ],
        ],
      ),
    );

    // Export: return panel as-is
    if (!fillHeight) return SizedBox(width: double.infinity, child: panel);

    // On-screen: auto-scale down (if needed) so it never scrolls
    return LayoutBuilder(builder: (ctx, cc) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(width: cc.maxWidth, child: panel),
      );
    });
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
  // Build
  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gradients = Theme.of(context).extension<AppGradients>();
    final bg = gradients?.page; // page gradient (light or dark)  [1](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/salah_table_generator.dart)

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

    //final paddingTop = MediaQuery.of(context).padding.top;
    final bottomSafe  = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: null, // no AppBar → keeps the “no header” look you like
      body: SafeArea(
        top: true, // fix: keep content below notch so the logo never gets clipped
        child: RepaintBoundary(
          key: _captureKey,
          child: Stack(
            children: [
              // PAGE CONTENT (gradient inside capture → exports match UI)
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(gradient: bg),
                    child: _generatorHeader(context),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(gradient: bg),
                      child: LayoutBuilder(
                        builder: (ctx, c) {
                          if (day == null) {
                            return Center(
                              child: Text(
                                l10n.msg_no_schedule,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            );
                          }
                          return (_layout == _LayoutKind.poster)
                              ? Padding(
                            padding: EdgeInsets.fromLTRB(
                              12, 0, 12, _hideChrome ? 12 : (_btnReserve + bottomSafe + 12),
                            ),
                            child: _posterPanel(
                              day,
                              c,
                              fillHeight: true,         // on-screen: fit without scroll
                              exportMode: _hideChrome,  // export: raw panel (no scaling)
                            ),
                          )
                              : Padding(
                            padding: EdgeInsets.only(
                                bottom: _hideChrome ? 0 : (_btnReserve + bottomSafe)),
                            child: KeyedSubtree(
                              key: const ValueKey('salah_table_glass_generator'),
                              child: SalahTable(
                                adhanByName: _adhanRaw(day),
                                iqamahByName: _iqamahRaw(day),
                                iqamahWidgetByName: _sunriseIqamahWidget(isLight),
                                highlightName: '__none__',
                                expandRowsToFill: true,
                                headerGreen: false,
                                headerBackgroundGradient: null,
                                headerBackgroundColor: Colors.transparent,
                                rowOddColor: Colors.transparent,
                                rowEvenColor: Colors.transparent,
                                highlightColor: AppColors.rowHighlight,
                                highlightColorLight: const Color(0xFFFFF0C9),
                                rowDividerColorLight:
                                const Color(0xFF7B90A0).withValues(alpha: 0.25),
                                rowDividerThickness: 0.8,
                                headerStyle: headerTextStyle,
                                nameStyle: nameTextStyle,
                                adhanStyle: valueTextStyle,
                                iqamahStyle: valueTextStyle,
                                order: _tableOrder(_isDstOn(_selected)),
                                useGlassSurface: true,
                                glassBlur: 8,
                                glassTintLight: Colors.white.withValues(alpha: 0.70),
                                glassTintDark: const Color(0xFF0A1E3A).withValues(alpha: 0.28),
                                glassBorderLight: Colors.white.withValues(alpha: 0.85),
                                glassBorderDark: const Color(0xFFC7A447).withValues(alpha: 0.40),
                                glassBorderWidth: 1.0,
                                glassRadius: BorderRadius.zero,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // OVERLAYS (hidden during export) ────────────────────────────
              if (!_hideChrome)
                Positioned(
                  // TOP‑LEFT Back button — anchored above the logo, inside SafeArea
                  left: _btnInset + 2,
                  top: _btnInset + 4, // a small nudge below the safe top
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.maybePop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: isLight ? const Color(0xFF0F2432) : Colors.white,
                      padding: const EdgeInsets.all(10),
                      shape: const CircleBorder(),
                    ),
                  ),
                ),

              if (!_hideChrome)
                Positioned(
                  // BOTTOM‑RIGHT Download button
                  right: _btnInset + 2,
                  bottom: _btnInset + bottomSafe,
                  child: IconButton(
                    onPressed: _selectedDay == null || _isExporting ? null : _exportPng,
                    icon: const Icon(Icons.download, size: 26),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: isLight ? const Color(0xFF0F2432) : Colors.white,
                      hoverColor: Colors.white24,
                      highlightColor: Colors.white24,
                      padding: const EdgeInsets.all(10),
                      shape: const CircleBorder(),
                    ),
                    tooltip: l10n.tip_download,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Editor: TextField + "Unknown (TBD)" checkbox
// ──────────────────────────────────────────────────────────────────────────────
class _FieldWithUnknown extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool unknown;
  final ValueChanged<bool> onUnknownChanged;
  final TextInputFormatter formatter;

  const _FieldWithUnknown({
    required this.label,
    required this.controller,
    required this.unknown,
    required this.onUnknownChanged,
    required this.formatter,
  });

  @override
  State<_FieldWithUnknown> createState() => _FieldWithUnknownState();
}

class _FieldWithUnknownState extends State<_FieldWithUnknown> {
  late bool _unknown;

  @override
  void initState() {
    super.initState();
    _unknown = widget.unknown;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          enabled: !_unknown,
          inputFormatters: [widget.formatter, LengthLimitingTextInputFormatter(48)],
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: l10n.label_unknown_tbd,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Checkbox(
              value: _unknown,
              onChanged: (v) {
                final next = v ?? false;
                setState(() => _unknown = next);
                widget.onUnknownChanged(next);
              },
            ),
            Text(l10n.label_unknown_tbd, style: TextStyle(color: cs.onSurface)),
          ],
        ),
      ],
    );
  }
}

class _KhateebResult {
  final String first;
  final String youth;
  _KhateebResult({required this.first, required this.youth});
}