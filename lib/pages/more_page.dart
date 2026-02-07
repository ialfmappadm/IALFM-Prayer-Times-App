// lib/pages/more_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';
import 'dart:io' show Platform;
import 'package:ialfm_prayer_times/services/exact_alarms.dart';

import '../main.dart' show AppGradients;
import '../app_colors.dart';
import '../theme_controller.dart';
import '../locale_controller.dart';
import '../ux_prefs.dart';
import '../services/hijri_override_service.dart';
import '../services/alerts_scheduler.dart';
import '../services/notification_optin_service.dart';
import '../models.dart';

// Aliased page imports to avoid symbol ambiguity
import './version_page.dart' as version_pg;
import './about_page.dart' as about_pg;
import './privacy_policy_page.dart' as privacy_pg;
import './terms_of_use_page.dart' as terms_pg;

class MorePage extends StatefulWidget {
  const MorePage({super.key});
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> with WidgetsBindingObserver {
  // ======= Comfortable layout tuning (matches Directory’s balanced styling) =======
  static const double _kListPadV = 16;   // ListView vertical padding
  static const double _kSectionGap = 12; // Gap between sections
  static const double _kHeaderVPad = 6;  // Section header top/bottom pad
  static const VisualDensity _kTileDensity =
  VisualDensity(horizontal: -1, vertical: -1.25); // ExpansionTile header density

  // ----- State -----
  static const String _adminPin = '3430';
  static const Color _gold = Color(0xFFC7A447);

  bool _notificationsExpanded = false;
  bool _accExpanded = false;
  bool _dateTimeExpanded = false;
  bool _langExpanded = false;
  bool _aboutExpanded = false;

  bool _adhanAlert = UXPrefs.adhanAlertEnabled.value;
  bool _iqamahAlert = UXPrefs.iqamahAlertEnabled.value;
  bool _jumuahReminder = UXPrefs.jumuahReminderEnabled.value;

  // Scroll + About anchor (for auto‑scroll)
  final _listController = ScrollController();
  final _aboutSectionKey = GlobalKey(); // key on the ABOUT card container
  final _aboutTileKey = GlobalKey();

  // --- OS notifications state label ---
  Future<String> _readOsNotificationStateLabel() async {
    try {
      final androidImpl = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final bool? enabled = await androidImpl?.areNotificationsEnabled();
      if (enabled == true) return 'Enabled';
      if (enabled == false) return 'Disabled';

      final fcm = await FirebaseMessaging.instance.getNotificationSettings();
      final auth = fcm.authorizationStatus;
      if (auth == AuthorizationStatus.authorized ||
          auth == AuthorizationStatus.provisional) {
        return 'Enabled';
      }
      if (auth == AuthorizationStatus.denied) return 'Disabled';
    } catch (_) {}
    return 'Check';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {}); // force FutureBuilder to refresh labels
    }
  }

  // ────────────────────────── BUILD ──────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final gradients = theme.extension<AppGradients>();
    final l10n = AppLocalizations.of(context);
    final appBarBg = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? const Color(0xFF0F2432) : Colors.white;
    final overlay = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.tab_more,
          style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: IconThemeData(color: titleColor),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradients?.page ?? AppColors.pageGradient),
        child: SafeArea(
          child: ListView(
            controller: _listController,
            padding: const EdgeInsets.fromLTRB(20, _kListPadV, 20, _kListPadV),
            children: [
              // ============= NOTIFICATIONS =============
              _sectionHeader(context, l10n.more_notifications),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    visualDensity: _kTileDensity,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: _notificationsExpanded,
                    onExpansionChanged: (v) => setState(() => _notificationsExpanded = v),
                    leading: _secIcon(FontAwesomeIcons.bell),
                    title: _secTitle(context, l10n.more_notifications),
                    children: [
                      // App notifications row → tappable row that opens bottom sheet
                      FutureBuilder<String>(
                        future: _readOsNotificationStateLabel(),
                        builder: (context, snap) {
                          final l10n = AppLocalizations.of(context);
                          final state = snap.data ?? 'Check';
                          final valueLabel = switch (state) {
                            'Enabled' => l10n.common_enabled,
                            'Disabled' => l10n.common_disabled,
                            _ => l10n.common_check,
                          };
                          return _pickerRow(
                            context: context,
                            icon: FontAwesomeIcons.bell,
                            label: l10n.more_app_notifications,
                            value: valueLabel,
                            onTap: _openNotificationsSheet,
                            alignValueRight: true,
                          );
                        },
                      ),
                      const _Hairline(),
                      // Salah Alerts
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.mosque,
                        label: l10n.more_prayer_alerts,
                        value: (_adhanAlert || _iqamahAlert)
                            ? '${l10n.more_adhan}: ${_toggleLabel(l10n, _adhanAlert)} · '
                            '${l10n.more_iqamah}: ${_toggleLabel(l10n, _iqamahAlert)}'
                            : l10n.common_open,
                        onTap: _openSalahSheet,
                        alignValueRight: true,
                      ),
                      const _Hairline(),
                      // Jumu’ah
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.handsPraying,
                        label: l10n.more_jumuah_reminder,
                        value: _jumuahReminder ? l10n.common_on : l10n.common_off,
                        onTap: _openJumuahSheet,
                        alignValueRight: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: _kSectionGap),

              // ============= ACCESSIBILITY =============
              _sectionHeader(context, l10n.more_accessibility),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    visualDensity: _kTileDensity,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: _accExpanded,
                    onExpansionChanged: (v) => setState(() => _accExpanded = v),
                    leading: _secIcon(FontAwesomeIcons.universalAccess),
                    title: _secTitle(context, l10n.more_accessibility),
                    children: [
                      // Dark Mode
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeController.themeMode,
                        builder: (context, mode, _) {
                          final platformDark =
                              MediaQuery.of(context).platformBrightness == Brightness.dark;
                          final isDark =
                              (mode == ThemeMode.dark) || (mode == ThemeMode.system && platformDark);
                          return _switchRow(
                            context: context,
                            icon: FontAwesomeIcons.moon,
                            label: l10n.more_dark_mode,
                            value: isDark,
                            onChanged: (v) {
                              ThemeController.setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
                              UXPrefs.maybeHaptic();
                            },
                          );
                        },
                      ),
                      const _Hairline(),
                      // Haptics
                      ValueListenableBuilder<bool>(
                        valueListenable: UXPrefs.hapticsEnabled,
                        builder: (context, enabled, _) {
                          return _switchRow(
                            context: context,
                            icon: FontAwesomeIcons.mobileScreenButton,
                            label: l10n.more_haptics,
                            value: enabled,
                            onChanged: (v) async => UXPrefs.setHapticsEnabled(v),
                          );
                        },
                      ),
                      const _Hairline(),
                      // Text Size
                      ValueListenableBuilder<double>(
                        valueListenable: UXPrefs.textScale,
                        builder: (context, scale, _) {
                          return _pickerRow(
                            context: context,
                            icon: FontAwesomeIcons.textHeight,
                            label: l10n.more_text_size,
                            value: UXPrefs.labelForScale(scale),
                            onTap: () async {
                              // Capture messenger BEFORE any await
                              final messenger = ScaffoldMessenger.of(context);
                              final options = const <String>['Small', 'Default', 'Large'];
                              final choice = await _chooseOne(
                                context,
                                title: l10n.more_text_size,
                                options: options,
                                selected: UXPrefs.labelForScale(UXPrefs.textScale.value),
                              );
                              if (!mounted || choice == null) return;
                              await UXPrefs.setTextScale(UXPrefs.scaleForLabel(choice));
                              if (!mounted) return;
                              UXPrefs.maybeHaptic();
                              messenger.showSnackBar(
                                SnackBar(content: Text('${l10n.more_text_size}: $choice')),
                              );
                              setState(() {});
                            },
                            alignValueRight: true,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: _kSectionGap),

              // ============= DATE & TIME =============
              _sectionHeader(context, l10n.more_date_time),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    visualDensity: _kTileDensity,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: _dateTimeExpanded,
                    onExpansionChanged: (v) => setState(() => _dateTimeExpanded = v),
                    leading: _secIcon(FontAwesomeIcons.clock),
                    title: _secTitle(context, l10n.more_date_time),
                    children: [
                      // TIME FORMAT
                      ValueListenableBuilder<bool>(
                        valueListenable: UXPrefs.use24h,
                        builder: (context, is24h, _) {
                          final segments = const <String>['12‑Hour', '24‑Hour'];
                          final selectedIndex = is24h ? 1 : 0;
                          return _segmentedRow(
                            context: context,
                            icon: FontAwesomeIcons.clock,
                            label: l10n.more_time_format,
                            segments: segments,
                            index: selectedIndex,
                            onChanged: (i) async {
                              // Capture messenger BEFORE await
                              final messenger = ScaffoldMessenger.of(context);
                              await UXPrefs.setUse24h(i == 1);
                              if (!mounted) return;
                              UXPrefs.maybeHaptic();
                              messenger.showSnackBar(
                                SnackBar(content: Text('${l10n.more_time_format}: ${segments[i]}')),
                              );
                              setState(() {});
                            },
                          );
                        },
                      ),
                      const _Hairline(),
                      // HIJRI OFFSET
                      ValueListenableBuilder<int>(
                        valueListenable: UXPrefs.hijriOffset,
                        builder: (context, offset, _) {
                          final l10n = AppLocalizations.of(context);
                          final segments = <String>[
                            l10n.more_hijri_offset_minus1,
                            l10n.more_hijri_offset_zero,
                            l10n.more_hijri_offset_plus1,
                          ];
                          final selectedIndex = offset + 1;
                          return _segmentedRow(
                            context: context,
                            icon: FontAwesomeIcons.moon,
                            label: l10n.more_hijri_offset_label,
                            segments: segments,
                            index: selectedIndex,
                            onChanged: (i) async {
                              // Capture messenger BEFORE await
                              final messenger = ScaffoldMessenger.of(context);
                              final newOffset = i - 1;
                              final ok = await _confirmHijriChange(segments[i]);
                              if (!mounted || !ok) return;
                              await UXPrefs.setHijriOffset(newOffset);
                              if (!mounted) return;
                              UXPrefs.maybeHaptic();
                              messenger.showSnackBar(
                                SnackBar(content: Text('${l10n.more_hijri_offset_label}: ${segments[i]}')),
                              );
                              setState(() {});
                            },
                          );
                        },
                      ),
                      const _Hairline(),
                      // Admin override
                      _buttonRow(
                        context: context,
                        icon: FontAwesomeIcons.triangleExclamation,
                        label: l10n.more_hijri_reset_label,
                        onPressed: () async {
                          // Capture messenger BEFORE awaits
                          final messenger = ScaffoldMessenger.of(context);
                          UXPrefs.maybeHaptic();
                          final pinOk = await _promptAdminPin();
                          if (!mounted || !pinOk) return;
                          final sure = await _confirmRunOverride();
                          if (!mounted || !sure) return;

                          final result = await HijriOverrideService.applyIfPresent(
                            resolveAppHijri: (g) async {
                              final h = HijriCalendar.fromDate(g);
                              return HijriYMD(h.hYear, h.hMonth, h.hDay);
                            },
                            log: true,
                          );
                          if (!mounted) return;
                          messenger.showSnackBar(SnackBar(content: Text(result.toString())));
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: _kSectionGap),

              // ============= LANGUAGE =============
              _sectionHeader(context, l10n.more_language),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    visualDensity: _kTileDensity,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: _langExpanded,
                    onExpansionChanged: (v) => setState(() => _langExpanded = v),
                    leading: _secIcon(FontAwesomeIcons.language),
                    title: _secTitle(context, l10n.more_language),
                    children: [
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.language,
                        label: l10n.more_language_label,
                        value: _currentLanguageLabel(context),
                        onTap: () async {
                          // Capture messenger BEFORE await
                          final messenger = ScaffoldMessenger.of(context);
                          final List<String> options = <String>[l10n.lang_english, l10n.lang_arabic];
                          final selectedNow = _currentLanguageLabel(context);
                          final choice = await _chooseOne(
                            context,
                            title: l10n.more_language,
                            options: options,
                            selected: selectedNow,
                          );
                          if (!mounted || choice == null) return;

                          if (choice == l10n.lang_arabic) {
                            LocaleController.setLocale(const Locale('ar'));
                          } else {
                            LocaleController.setLocale(const Locale('en'));
                          }
                          UXPrefs.maybeHaptic();
                          messenger.showSnackBar(
                            SnackBar(content: Text('${l10n.more_language}: $choice')),
                          );
                          setState(() {});
                        },
                        alignValueRight: true,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: _kSectionGap),

              // ============= ABOUT (auto‑scroll on expand) =============
              _sectionHeader(context, l10n.more_about),
              Container( // key on the container wrapping the card (more reliable anchor)
                key: _aboutSectionKey,
                child: _card(
                  context,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      visualDensity: _kTileDensity,
                    ),
                    child: ExpansionTile(
                      key: _aboutTileKey,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      initiallyExpanded: _aboutExpanded,
                      onExpansionChanged: (v) {
                        setState(() => _aboutExpanded = v);
                        if (v) _scrollToAbout(); // no await; lint‑safe
                      },
                      leading: _secIcon(FontAwesomeIcons.circleInfo),
                      title: _secTitle(context, l10n.more_about),
                      children: [
                        // App Version
                        _pickerRow(
                          context: context,
                          icon: FontAwesomeIcons.tag,
                          label: l10n.more_app_version,
                          value: '',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => version_pg.VersionInfoPage()),
                          ),
                          hideValue: true,
                        ),
                        const _Hairline(),

                        // About App
                        _pickerRow(
                          context: context,
                          icon: FontAwesomeIcons.info,
                          label: l10n.more_about_app,
                          value: '',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => about_pg.AboutPage()),
                          ),
                          hideValue: true,
                        ),
                        const _Hairline(),

                        // Privacy Policy
                        _pickerRow(
                          context: context,
                          icon: FontAwesomeIcons.shieldHalved,
                          label: l10n.more_privacy_policy,
                          value: '',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => privacy_pg.PrivacyPolicyPage()),
                          ),
                          hideValue: true,
                        ),
                        const _Hairline(),

                        // Terms of Use
                        _pickerRow(
                          context: context,
                          icon: FontAwesomeIcons.scaleBalanced,
                          label: l10n.more_terms_of_use,
                          value: '',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => terms_pg.TermsOfUsePage()),
                          ),
                          hideValue: true,
                        ),
                        const _Hairline(),

                        // Contact Sheet
                        _pickerRow(
                          context: context,
                          icon: FontAwesomeIcons.envelope,
                          label: l10n.more_contact,
                          value: '',
                          onTap: () => _showContactSheet(context),
                          hideValue: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────── Sheets & Scheduling ──────────────────────────

  Future<void> _openNotificationsSheet() async {
    final bottomSheetBg = Theme.of(context).bottomSheetTheme.backgroundColor; // capture first
    final String state = await _readOsNotificationStateLabel();
    final bool isEnabled = state == 'Enabled';
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: bottomSheetBg,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final l10n = AppLocalizations.of(ctx);
        const gold = Color(0xFFC7A447);

        Future<void> openSettingsAndRefresh() async {
          Navigator.pop(ctx);
          await UXPrefs.setLastIntendedTab('more');
          await NotificationOptInService.openOSSettings();
          if (!mounted) return;
          setState(() {}); // refresh the row
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.more_app_notifications_title,
                  style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: gold, foregroundColor: Colors.black,
                    ),
                    onPressed: openSettingsAndRefresh,
                    child: Text(
                      isEnabled
                          ? l10n.more_notifications_disable_in_settings
                          : l10n.more_notifications_open_settings,
                    ),
                  ),
                ),

                // EXACT Alarms setting path on Android only
                if (Platform.isAndroid) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.alarm_on_outlined),
                      label: Text(AppLocalizations.of(context).allowExactAlarms),
                      onPressed: () async {
                        Navigator.pop(ctx); // close sheet
                        await openExactAlarmsSettings(); // system page
                        if (!mounted) return;
                        await _rescheduleToday();
                        setState(() {});
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(l10n.btn_close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() {}); // refresh row even if dismissed
  }

  Future<void> _openSalahSheet() async {
    final l10n = AppLocalizations.of(context);
    bool tempAdhan = _adhanAlert;
    bool tempIqamah = _iqamahAlert;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Salah Alerts',
                        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      title: Text(l10n.more_adhan_alert_at_time),
                      value: tempAdhan,
                      onChanged: (v) => setSheetState(() => tempAdhan = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile.adaptive(
                      title: Text(l10n.more_iqamah_alert_5min),
                      value: tempIqamah,
                      onChanged: (v) => setSheetState(() => tempIqamah = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l10n.btn_close),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: _gold, foregroundColor: Colors.black),
                            onPressed: () async {
                              // Capture messenger BEFORE awaits
                              final messenger = ScaffoldMessenger.of(context);

                              Navigator.pop(ctx);
                              if (!mounted) return;

                              _adhanAlert = tempAdhan;
                              _iqamahAlert = tempIqamah;
                              await UXPrefs.setAdhanAlertEnabled(_adhanAlert);
                              await UXPrefs.setIqamahAlertEnabled(_iqamahAlert);
                              await AlertsScheduler.instance.requestPermissions();
                              await _rescheduleToday();
                              if (!mounted) return;

                              messenger.showSnackBar(SnackBar(content: Text(l10n.common_enabled)));
                              setState(() {});
                            },
                            child: Text(l10n.btn_save),
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
      },
    );
  }

  Future<void> _openJumuahSheet() async {
    bool temp = _jumuahReminder;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final l10n = AppLocalizations.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.more_jumuah_reminder,
                        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      title: Text(l10n.more_jumuah_reminder_label),
                      value: temp,
                      onChanged: (v) => setSheetState(() => temp = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(l10n.btn_close),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _gold, foregroundColor: Colors.black,
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              if (!mounted) return;
                              _jumuahReminder = temp;
                              await UXPrefs.setJumuahReminderEnabled(_jumuahReminder);
                              await AlertsScheduler.instance.requestPermissions();
                              await _rescheduleToday();
                              if (!mounted) return;
                              setState(() {});
                            },
                            child: Text(l10n.btn_save),
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
      },
    );
  }

  Future<void> _rescheduleToday() async {
    final now = DateTime.now();
    final days = await loadPrayerDays(year: now.year);
    final todayDate = DateTime(now.year, now.month, now.day);
    PrayerDay? today;
    for (final d in days) {
      if (d.date.year == todayDate.year &&
          d.date.month == todayDate.month &&
          d.date.day == todayDate.day) {
        today = d; break;
      }
    }
    if (today == null) return;

    DateTime? mkTime(DateTime base, String hhmm) {
      if (hhmm.isEmpty) return null;
      final p = hhmm.split(':');
      if (p.length != 2) return null;
      final h = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      if (h == null || m == null) return null;
      return DateTime(base.year, base.month, base.day, h, m);
    }

    final base = DateTime(today.date.year, today.date.month, today.date.day);
    // Adhan
    final fajrAdhan = mkTime(base, today.prayers['fajr']?.begin ?? '');
    final dhuhrAdhan = mkTime(base, today.prayers['dhuhr']?.begin ?? '');
    final asrAdhan = mkTime(base, today.prayers['asr']?.begin ?? '');
    final maghribAdhan = mkTime(base, today.prayers['maghrib']?.begin ?? '');
    final ishaAdhan = mkTime(base, today.prayers['isha']?.begin ?? '');
    // Iqamah
    final fajrIqamah = mkTime(base, today.prayers['fajr']?.iqamah ?? '');
    final dhuhrIqamah = mkTime(base, today.prayers['dhuhr']?.iqamah ?? '');
    final asrIqamah = mkTime(base, today.prayers['asr']?.iqamah ?? '');
    final maghribIqamah = mkTime(base, today.prayers['maghrib']?.iqamah ?? '');
    final ishaIqamah = mkTime(base, today.prayers['isha']?.iqamah ?? '');

    await AlertsScheduler.instance.schedulePrayerAlertsForDay(
      dateLocal: base,
      fajrAdhan: fajrAdhan,
      dhuhrAdhan: dhuhrAdhan,
      asrAdhan: asrAdhan,
      maghribAdhan: maghribAdhan,
      ishaAdhan: ishaAdhan,
      fajrIqamah: fajrIqamah,
      dhuhrIqamah: dhuhrIqamah,
      asrIqamah: asrIqamah,
      maghribIqamah: maghribIqamah,
      ishaIqamah: ishaIqamah,
      adhanEnabled: _adhanAlert,
      iqamahEnabled: _iqamahAlert,
    );
    await AlertsScheduler.instance.scheduleJumuahReminderForWeek(
      anyDateThisWeekLocal: base,
      enabled: _jumuahReminder,
    );
  }

  // ────────────────────────── Admin/Confirm helpers ──────────────────────────

  Future<bool> _confirmHijriChange(String selectionLabel) async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.more_hijri_offset_label),
        content: Text('${l10n.more_hijri_offset_label}: $selectionLabel ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.btn_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.btn_save),
          ),
        ],
      ),
    ).then((v) => v ?? false);
  }

  Future<bool> _promptAdminPin() async {
    final messenger = ScaffoldMessenger.of(context); // capture BEFORE awaits
    final controller = TextEditingController();
    bool ok = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Admin Verification'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'Enter Admin PIN',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(ctx).btn_cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                ok = (controller.text == _adminPin);
                Navigator.pop(ctx);
              },
              child: Text(AppLocalizations.of(ctx).btn_save),
            ),
          ],
        );
      },
    );
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Invalid PIN')));
    }
    return ok;
  }

  Future<bool> _confirmRunOverride() async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Hijri Date from Masjid'),
        content: const Text(
          'This will update today’s Hijri date based on the masjid’s official setting.\nProceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.btn_cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.btn_save),
          ),
        ],
      ),
    ).then((v) => v ?? false);
  }

  static Future<void> _showContactSheet(BuildContext context) async {
    const gold = Color(0xFFC7A447);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Contact IALFM',
                    style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.feedback_outlined),
                  title: const Text('Feedback / Features'),
                  subtitle: const Text('ialfm.app.adm@gmail.com'),
                  onTap: () => _launchMail('ialfm.app.adm@gmail.com', ctx),
                ),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Board / Governance'),
                  subtitle: const Text('bod@ialfm.org'),
                  onTap: () => _launchMail('bod@ialfm.org', ctx),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _launchMail(String to, BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context); // capture BEFORE await
    final uri = Uri.parse('mailto:$to');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open email app for $to')),
      );
    }
  }

  // ────────────────────────── Shared UI helpers ──────────────────────────

  String _toggleLabel(AppLocalizations l10n, bool v) => v ? l10n.common_on : l10n.common_off;

  /// Shared label style so sub-option rows match across pages.
  TextStyle _rowLabelStyle(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final base = theme.textTheme.titleMedium ?? const TextStyle(fontSize: 16);
    return base.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700);
  }

  Widget _sectionHeader(BuildContext context, String title) {
    const gold = Color(0xFFC7A447);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, _kHeaderVPad, 2, _kHeaderVPad),
      child: Text(
        title,
        style: const TextStyle(
          color: gold,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.rowHighlight
        : Color.alphaBlend(cs.primary.withValues(alpha: 0.05), cs.surface);
    final hairline =
    isDark ? Colors.white.withValues(alpha: 0.08) : cs.outline.withValues(alpha: 0.30);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hairline),
      ),
      child: child,
    );
  }

  Widget _secIcon(IconData icon) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: FaIcon(icon, size: 18),
  );

  Widget _secTitle(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _switchRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: {
          FaIcon(icon, size: 18, color: cs.onSurface),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: _rowLabelStyle(context), // ← unified label style
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        }.toList(),
      ),
    );
  }

  /// Enhanced picker row with optional right‑alignment & hiding of value text
  Widget _pickerRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    bool alignValueRight = false,
    bool hideValue = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final showValue = !hideValue && value.trim().isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FaIcon(icon, size: 18, color: cs.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: _rowLabelStyle(context), // ← unified label style
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (alignValueRight) const Spacer(),
            if (showValue) ...[
              Flexible(
                child: Align(
                  alignment: alignValueRight ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(
                    value,
                    textAlign: alignValueRight ? TextAlign.right : TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buttonRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          FaIcon(icon, size: 18, color: cs.onSurface),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: _rowLabelStyle(context), // ← unified label style
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FilledButton.tonal(onPressed: onPressed, child: const Text('Open')),
        ],
      ),
    );
  }

  Widget _segmentedRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required List<String> segments,
    required int index,
    required ValueChanged<int> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            FaIcon(icon, size: 18, color: cs.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: _rowLabelStyle(context), // ← unified label style
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: List.generate(
              segments.length,
                  (i) => ButtonSegment(value: i, label: Text(segments[i])),
            ),
            selected: {index},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }

  Future<String?> _chooseOne(
      BuildContext context, {
        required String title,
        required List<String> options,
        required String selected,
      }) async {
    int tempIndex = options.indexOf(selected);
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final l10n = AppLocalizations.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        title,
                        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SegmentedButton<int>(
                      segments: List.generate(
                        options.length,
                            (i) => ButtonSegment<int>(value: i, label: Text(options[i])),
                      ),
                      selected: {tempIndex},
                      onSelectionChanged: (s) => setModalState(() => tempIndex = s.first),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, selected),
                            child: Text(l10n.btn_cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _gold,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () => Navigator.pop(ctx, options[tempIndex]),
                            child: Text(l10n.btn_save),
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
      },
    );
  }

  String _currentLanguageLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = LocaleController.locale.value?.languageCode;
    return (code == 'ar') ? l10n.lang_arabic : l10n.lang_english;
  }

  // Smoothly scroll About into view after it expands (lint‑clean, no async/await)
  void _scrollToAbout() {
    void tryScroll({Duration duration = const Duration(milliseconds: 250)}) {
      // Always read a *fresh* context at the moment we scroll.
      final ctx = _aboutTileKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: duration,
          curve: Curves.easeInOutCubic,
          alignment: 0.0, // adjust to 0.02 if you want a hair of spacing under the AppBar
        );
      }
    }

    // 1) Right after the first re-layout (expansion has just begun).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tryScroll(duration: const Duration(milliseconds: 250));
    });

    // 2) Near the end of the ExpansionTile animation.
    Future.delayed(const Duration(milliseconds: 220), tryScroll);

    // 3) Optional final nudge for slower devices / longer animations.
    Future.delayed(const Duration(milliseconds: 400), tryScroll);
  }
}

// Separator used in lists
class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.30),
    indent: 12,
    endIndent: 12,
  );
}