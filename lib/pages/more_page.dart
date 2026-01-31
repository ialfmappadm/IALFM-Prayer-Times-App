// lib/pages/more_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show AppGradients;
import '../app_colors.dart';
import '../theme_controller.dart';
import '../locale_controller.dart';
import '../ux_prefs.dart';
import '../services/hijri_override_service.dart';
import '../services/notification_optin_service.dart';
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Scheduling local notifications
import '../services/alerts_scheduler.dart';            // Alerts scheduler (local notifications)
// Load & parse today’s prayer times for scheduling
//import '../utils/time_utils.dart';                     // loadPrayerDays()
import '../models.dart';                               // PrayerDay model

class MorePage extends StatefulWidget {
  const MorePage({super.key});
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  String _appVersion = '—';

  // Admin PIN
  static const String _adminPin = '3430';

  // Expanded flags
  bool _accExpanded = false;
  bool _dateTimeExpanded = false;
  bool _langExpanded = false;

  // Notifications & About sections
  bool _notificationsExpanded = false;
  bool _aboutExpanded = false;

  // Prayer Alerts (UI toggles; persisted via UXPrefs)
  bool _adhanAlert = false;
  bool _iqamahAlert = false;

  // Jumu'ah Reminder (UI toggle; persisted via UXPrefs)
  bool _jumuahReminder = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    // Load persisted toggles on open
    _adhanAlert     = UXPrefs.adhanAlertEnabled.value;     // persisted toggle (UXPrefs)  [1](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/alerts_scheduler.dart)
    _iqamahAlert    = UXPrefs.iqamahAlertEnabled.value;    // persisted toggle (UXPrefs)  [1](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/alerts_scheduler.dart)
    _jumuahReminder = UXPrefs.jumuahReminderEnabled.value; // persisted toggle (UXPrefs)  [1](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/alerts_scheduler.dart)
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = '${info.version} (${info.buildNumber})');
    } catch (_) {
      // keep placeholder
    }
  }

  String _currentLanguageLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = LocaleController.locale.value?.languageCode;
    return (code == 'ar') ? l10n.lang_arabic : l10n.lang_english;
  }

  void _applyLanguageChoice(String choice, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (choice == l10n.lang_arabic) {
      LocaleController.setLocale(const Locale('ar'));
    } else {
      LocaleController.setLocale(const Locale('en'));
    }
  }

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
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.btn_save),
          ),
        ],
      ),
    ).then((v) => v ?? false);
  }

  Future<bool> _promptAdminPin() async {
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
              child: Text(AppLocalizations.of(context).btn_cancel),
            ),
            FilledButton(
              onPressed: () {
                ok = (controller.text == _adminPin);
                Navigator.pop(ctx);
              },
              child: Text(AppLocalizations.of(context).btn_save),
            ),
          ],
        );
      },
    );
    if (!ok) {
      _toast('Invalid PIN');
    }
    return ok;
  }

  Future<bool> _confirmRunOverride() async {
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
            child: Text(AppLocalizations.of(context).btn_cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).btn_save),
          ),
        ],
      ),
    ).then((v) => v ?? false);
  }

  // (Re)schedule alerts for TODAY based on toggles
  Future<void> _rescheduleTodayAlerts({
    required bool adhan,
    required bool iqamah,
    required bool jumuah,
  }) async {
    final now = DateTime.now();
    final days = await loadPrayerDays(year: now.year);     // local JSON loader (already used at startup)  [1](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/alerts_scheduler.dart)
    final todayDate = DateTime(now.year, now.month, now.day);

    PrayerDay? today;
    for (final d in days) {
      if (d.date.year == todayDate.year &&
          d.date.month == todayDate.month &&
          d.date.day == todayDate.day) {
        today = d;
        break;
      }
    }
    if (today == null) return;

    DateTime? mkTime(DateTime base, String hhmm) {
      if (hhmm.isEmpty) return null;
      final parts = hhmm.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return DateTime(base.year, base.month, base.day, h, m);
    }

    final base = DateTime(today.date.year, today.date.month, today.date.day);

    // Adhan
    final fajrAdhan     = mkTime(base, today.prayers['fajr']?.begin    ?? '');
    final dhuhrAdhan    = mkTime(base, today.prayers['dhuhr']?.begin   ?? '');
    final asrAdhan      = mkTime(base, today.prayers['asr']?.begin     ?? '');
    final maghribAdhan  = mkTime(base, today.prayers['maghrib']?.begin ?? '');
    final ishaAdhan     = mkTime(base, today.prayers['isha']?.begin    ?? '');

    // Iqamah
    final fajrIqamah    = mkTime(base, today.prayers['fajr']?.iqamah    ?? '');
    final dhuhrIqamah   = mkTime(base, today.prayers['dhuhr']?.iqamah   ?? '');
    final asrIqamah     = mkTime(base, today.prayers['asr']?.iqamah     ?? '');
    final maghribIqamah = mkTime(base, today.prayers['maghrib']?.iqamah ?? '');
    final ishaIqamah    = mkTime(base, today.prayers['isha']?.iqamah    ?? '');

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
      adhanEnabled: adhan,
      iqamahEnabled: iqamah,
    ); // schedules high-importance local notifications (Android) & alert/sound on iOS  [2](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/more_page.dart)

    await AlertsScheduler.instance.scheduleJumuahReminderForWeek(
      anyDateThisWeekLocal: base,
      enabled: jumuah,
    ); // weekly Friday reminder  [2](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/more_page.dart)
  }

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
        ),
        iconTheme: IconThemeData(color: titleColor),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradients?.page ?? AppColors.pageGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              // ============= NOTIFICATIONS =============
              _sectionHeader(context, l10n.more_notifications),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: _notificationsExpanded,
                    onExpansionChanged: (v) => setState(() => _notificationsExpanded = v),
                    leading: _secIcon(FontAwesomeIcons.bell),
                    title: _secTitle(context, l10n.more_notifications),
                    children: [
                      // Enable Notifications (tap → OS Settings), with buttons
                      FutureBuilder<NotificationSettings>(
                        future: NotificationOptInService.getStatus(),
                        builder: (context, snap) {
                          String value = '…';
                          VoidCallback onTap = () {};
                          bool showEnableButton = false;
                          if (snap.hasData) {
                            final s = snap.data!;
                            final authorized = NotificationOptInService.isAuthorized(s);
                            final denied = s.authorizationStatus == AuthorizationStatus.denied;
                            if (authorized) {
                              value = l10n.common_enabled;
                              onTap = () async {
                                await NotificationOptInService.openOSSettings();
                              };
                              showEnableButton = false;
                            } else if (denied) {
                              value = l10n.common_disabled;
                              onTap = () async {
                                await NotificationOptInService.openOSSettings();
                              };
                              showEnableButton = true;
                            } else {
                              value = l10n.common_disabled;
                              onTap = () async {
                                await NotificationOptInService.openOSSettings();
                              };
                              showEnableButton = true;
                            }
                          }
                          return Column(
                            children: [
                              _pickerRow(
                                context: context,
                                icon: FontAwesomeIcons.bell,
                                label: l10n.more_enable_notifications,
                                value: value,
                                onTap: onTap,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () async {
                                          await NotificationOptInService.openOSSettings();
                                        },
                                        child: Text(l10n.common_open_settings),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (showEnableButton)
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () async {
                                            final after = await NotificationOptInService.requestPermission();
                                            if (!context.mounted) return;
                                            final ok = NotificationOptInService.isAuthorized(after);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(ok
                                                  ? l10n.common_enabled
                                                  : l10n.common_disabled)),
                                            );
                                            setState(() {});
                                          },
                                          child: Text(l10n.common_enable),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const _Hairline(),

                      // Prayer Alerts (Adhan / Iqamah)
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.mosque,
                        label: l10n.more_prayer_alerts,
                        value: (_adhanAlert || _iqamahAlert)
                            ? '${l10n.more_adhan}: ${_toggleLabel(_adhanAlert)} · ${l10n.more_iqamah}: ${_toggleLabel(_iqamahAlert)}'
                            : l10n.common_open,
                        onTap: _configurePrayerAlerts,
                      ),
                      const _Hairline(),

                      // Jumu'ah Reminder
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.handsPraying,
                        label: l10n.more_jumuah_reminder,
                        value: _jumuahReminder ? l10n.more_jumuah_on : l10n.more_jumuah_off,
                        onTap: () async {
                          final enabled = await _toggleJumuahReminder();
                          if (!context.mounted) return;
                          setState(() {
                            _jumuahReminder = enabled ?? _jumuahReminder;
                          });

                          // Persist and (re)schedule immediately
                          await UXPrefs.setJumuahReminderEnabled(_jumuahReminder);   // persist  [1](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/alerts_scheduler.dart)
                          await AlertsScheduler.instance.requestPermissions();        // OS permission  [2](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/more_page.dart)
                          await _rescheduleTodayAlerts(                              // schedule locally  [2](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/more_page.dart)
                            adhan: UXPrefs.adhanAlertEnabled.value,
                            iqamah: UXPrefs.iqamahAlertEnabled.value,
                            jumuah: UXPrefs.jumuahReminderEnabled.value,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= ACCESSIBILITY =============
              _sectionHeader(context, AppLocalizations.of(context).more_accessibility),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: _accExpanded,
                    onExpansionChanged: (v) => setState(() => _accExpanded = v),
                    leading: _secIcon(FontAwesomeIcons.universalAccess),
                    title: _secTitle(context, AppLocalizations.of(context).more_accessibility),
                    children: [
                      // Dark Mode
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeController.themeMode,
                        builder: (context, mode, _) {
                          final platformDark =
                              MediaQuery.of(context).platformBrightness == Brightness.dark;
                          final isDark = (mode == ThemeMode.dark)
                              || (mode == ThemeMode.system && platformDark);
                          return _switchRow(
                            context: context,
                            icon: FontAwesomeIcons.moon,
                            label: AppLocalizations.of(context).more_dark_mode,
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
                            label: AppLocalizations.of(context).more_haptics,
                            value: enabled,
                            onChanged: (v) async {
                              await UXPrefs.setHapticsEnabled(v);
                            },
                          );
                        },
                      ),
                      const _Hairline(),

                      // Text Size picker
                      ValueListenableBuilder<double>(
                        valueListenable: UXPrefs.textScale,
                        builder: (context, scale, _) {
                          return _pickerRow(
                            context: context,
                            icon: FontAwesomeIcons.textHeight,
                            label: AppLocalizations.of(context).more_text_size,
                            value: UXPrefs.labelForScale(scale),
                            onTap: () async {
                              final options = const <String>['Small', 'Default', 'Large'];
                              final choice = await _chooseOne(
                                context,
                                title: AppLocalizations.of(context).more_text_size,
                                options: options,
                                selected: UXPrefs.labelForScale(UXPrefs.textScale.value),
                              );
                              if (!context.mounted) return;
                              if (choice == null) return;
                              await UXPrefs.setTextScale(UXPrefs.scaleForLabel(choice));
                              if (!context.mounted) return;
                              UXPrefs.maybeHaptic();
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= DATE & TIME =============
              _sectionHeader(context, AppLocalizations.of(context).more_date_time),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: _dateTimeExpanded,
                    onExpansionChanged: (v) => setState(() => _dateTimeExpanded = v),
                    leading: _secIcon(FontAwesomeIcons.clock),
                    title: _secTitle(context, AppLocalizations.of(context).more_date_time),
                    children: [
                      // TIME FORMAT (12/24h)
                      ValueListenableBuilder<bool>(
                        valueListenable: UXPrefs.use24h,
                        builder: (context, is24h, _) {
                          final segments = const <String>['12‑Hour', '24‑Hour'];
                          final selectedIndex = is24h ? 1 : 0;
                          return _segmentedRow(
                            context: context,
                            icon: FontAwesomeIcons.clock,
                            label: AppLocalizations.of(context).more_time_format,
                            segments: segments,
                            index: selectedIndex,
                            onChanged: (i) async {
                              await UXPrefs.setUse24h(i == 1);
                              if (!context.mounted) return;
                              UXPrefs.maybeHaptic();
                              _toast('${AppLocalizations.of(context).more_time_format}: ${segments[i]}');
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
                              final newOffset = i - 1;
                              final ok = await _confirmHijriChange(segments[i]);
                              if (!context.mounted) return;
                              if (!ok) return;
                              await UXPrefs.setHijriOffset(newOffset);
                              if (!context.mounted) return;
                              UXPrefs.maybeHaptic();
                              _toast('${l10n.more_hijri_offset_label}: ${segments[i]}');
                              setState(() {});
                            },
                          );
                        },
                      ),
                      const _Hairline(),

                      // Admin-only override
                      _buttonRow(
                        context: context,
                        icon: FontAwesomeIcons.lock,
                        label: 'Update Hijri Date from Masjid (Admin)',
                        onPressed: () async {
                          UXPrefs.maybeHaptic();
                          final pinOk = await _promptAdminPin();
                          if (!context.mounted) return;
                          if (!pinOk) return;
                          final sure = await _confirmRunOverride();
                          if (!context.mounted) return;
                          if (!sure) return;
                          final result = await HijriOverrideService.applyIfPresent(
                            resolveAppHijri: (g) async {
                              final h = HijriCalendar.fromDate(g);
                              return HijriYMD(h.hYear, h.hMonth, h.hDay);
                            },
                            // bucketOverride: 'gs://ialfm-prayer-times.firebasestorage.app',
                            log: true,
                          );
                          if (!context.mounted) return;
                          _toast(result.toString());
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= LANGUAGE =============
              _sectionHeader(context, AppLocalizations.of(context).more_language),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: _langExpanded,
                    onExpansionChanged: (v) => setState(() => _langExpanded = v),
                    leading: _secIcon(FontAwesomeIcons.language),
                    title: _secTitle(context, AppLocalizations.of(context).more_language),
                    children: [
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.language,
                        label: AppLocalizations.of(context).more_language_label,
                        value: _currentLanguageLabel(context),
                        onTap: () async {
                          final l10n = AppLocalizations.of(context);
                          final List<String> options = <String>[l10n.lang_english, l10n.lang_arabic];
                          final selectedNow = _currentLanguageLabel(context);
                          final choice = await _chooseOne(
                            context,
                            title: l10n.more_language,
                            options: options,
                            selected: selectedNow,
                          );
                          if (!context.mounted) return;
                          if (choice == null) return;
                          _applyLanguageChoice(choice, context);
                          UXPrefs.maybeHaptic();
                          _toast('${l10n.more_language}: $choice');
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= ABOUT =============
              _sectionHeader(context, AppLocalizations.of(context).more_about),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: _aboutExpanded,
                    onExpansionChanged: (v) => setState(() => _aboutExpanded = v),
                    leading: _secIcon(FontAwesomeIcons.circleInfo),
                    title: _secTitle(context, AppLocalizations.of(context).more_about),
                    children: [
                      _staticRow(
                        context: context,
                        icon: FontAwesomeIcons.tag,
                        label: AppLocalizations.of(context).more_version,
                        trailing: Text(_appVersion),
                      ),
                      const _Hairline(),
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.info,
                        label: AppLocalizations.of(context).more_about_app,
                        value: AppLocalizations.of(context).common_open,
                        onTap: () => _openMarkdownSheet(
                          title: AppLocalizations.of(context).more_about_app,
                          body: AppLocalizations.of(context).more_about_app_body,
                        ),
                      ),
                      const _Hairline(),
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.shieldHalved,
                        label: AppLocalizations.of(context).more_privacy_policy,
                        value: AppLocalizations.of(context).common_open,
                        onTap: () => _openMarkdownSheet(
                          title: AppLocalizations.of(context).more_privacy_policy,
                          body: _privacyPolicyText, // keep static or localize as needed
                        ),
                      ),
                      const _Hairline(),
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.triangleExclamation,
                        label: AppLocalizations.of(context).more_disclaimer,
                        value: AppLocalizations.of(context).common_open,
                        onTap: () => _openMarkdownSheet(
                          title: AppLocalizations.of(context).more_disclaimer,
                          body: _disclaimerText,
                        ),
                      ),
                      const _Hairline(),
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.scaleBalanced,
                        label: AppLocalizations.of(context).more_licensing,
                        value: AppLocalizations.of(context).common_open,
                        onTap: () => _openMarkdownSheet(
                          title: AppLocalizations.of(context).more_licensing,
                          body: _licensingText,
                        ),
                      ),
                      const _Hairline(),
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.envelope,
                        label: AppLocalizations.of(context).more_contact,
                        value: AppLocalizations.of(context).common_open,
                        onTap: _openContactSheet,
                      ),
                    ],
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

  // ───────────── Notifications UI helpers ─────────────
  String _toggleLabel(bool v) => v ? 'On' : 'Off'; // keep concise English for combined value row

  Future<void> _configurePrayerAlerts() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.more_prayer_alerts,
                        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      title: Text(l10n.more_adhan_alert_at_time),
                      value: _adhanAlert,
                      onChanged: (v) => setModalState(() => _adhanAlert = v),
                    ),
                    SwitchListTile.adaptive(
                      title: Text(l10n.more_iqamah_alert_5min),
                      value: _iqamahAlert,
                      onChanged: (v) => setModalState(() => _iqamahAlert = v),
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
                            onPressed: () async {
                              Navigator.pop(ctx);
                              if (!mounted) return;

                              // Persist toggles
                              await UXPrefs.setAdhanAlertEnabled(_adhanAlert);   // persist  [1](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/alerts_scheduler.dart)
                              await UXPrefs.setIqamahAlertEnabled(_iqamahAlert); // persist  [1](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/alerts_scheduler.dart)

                              // Ensure OS permission (Android 13+/iOS prompt as needed)
                              await AlertsScheduler.instance.requestPermissions(); // permission  [2](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/more_page.dart)

                              // Schedule for TODAY using persisted values
                              await _rescheduleTodayAlerts(                     // local notifications  [2](https://ialfm-my.sharepoint.com/personal/syed_ialfm_org/Documents/Microsoft%20Copilot%20Chat%20Files/more_page.dart)
                                adhan: UXPrefs.adhanAlertEnabled.value,
                                iqamah: UXPrefs.iqamahAlertEnabled.value,
                                jumuah: UXPrefs.jumuahReminderEnabled.value,
                              );

                              if (!mounted) return;
                              _toast(l10n.common_enabled);
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

  Future<bool?> _toggleJumuahReminder() async {
    bool temp = _jumuahReminder;
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.more_jumuah_reminder),
        content: const Text("Send a friendly reminder 1 hour before Jumu’ah."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, temp),
            child: Text(l10n.btn_cancel),
          ),
          StatefulBuilder(
            builder: (ctx, setDialogState) {
              return Row(
                children: [
                  const SizedBox(width: 12),
                  Text(l10n.common_enable),
                  const Spacer(),
                  Switch.adaptive(
                    value: temp,
                    onChanged: (v) => setDialogState(() => temp = v),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, temp),
            child: Text(l10n.btn_save),
          ),
        ],
      ),
    );
  }

  // ───────────── About helpers ─────────────
  Future<void> _openMarkdownSheet({required String title, required String body}) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      body,
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.85)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(AppLocalizations.of(context).btn_close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openContactSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Contact IALFM', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.feedback_outlined),
                  title: const Text('Feedback / Features'),
                  subtitle: const Text('ialfm.app.adm@gmail.com'),
                  onTap: () => _launchMail('ialfm.app.adm@gmail.com'),
                ),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Board / Governance'),
                  subtitle: const Text('bod@ialfm.org'),
                  onTap: () => _launchMail('bod@ialfm.org'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(AppLocalizations.of(context).btn_close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchMail(String to) async {
    final uri = Uri.parse('mailto:$to');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open email app for $to')),
      );
    }
  }

  // ───────────── Shared UI helpers ─────────────
  Widget _sectionHeader(BuildContext context, String title) {
    const gold = Color(0xFFC7A447);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: gold, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? Color.alphaBlend(const Color(0xFF132C3B).withValues(alpha: 0.35), const Color(0xFF0E2330))
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
    return Text(title, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700));
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
        children: [
          FaIcon(icon, size: 18, color: cs.onSurface),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700))),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// If [value] is an empty string, the trailing value text is hidden entirely.
  Widget _pickerRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    final showValue = value.trim().isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            FaIcon(icon, size: 18, color: cs.onSurface),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700))),
            if (showValue) ...[
              Text(value, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8))),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, size: 14),
          ],
        ),
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
            Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
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

  Widget _staticRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          FaIcon(icon, size: 18, color: cs.onSurface),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700))),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ⬇️ Restored helper: was missing in last drop; required by the Admin row
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
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton.tonal(onPressed: onPressed, child: const Text('Open')),
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
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
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
                      child: Text(title, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
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

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Static policy blocks (can be localized later if you prefer)
  static const String _privacyPolicyText =
      'We do not collect personal CPNI or sensitive personal data. We may store non‑identifying app settings on your device (e.g., theme, language, Hijri offset). Push notifications are used solely to deliver masjid announcements and time‑sensitive updates; you can manage notifications in your device Settings. We do not sell or share personal data with third parties.';

  static const String _disclaimerText = '''
Important Disclaimer
This app is built and maintained by community volunteers and is provided as‑is, without warranties of any kind. IALFM and the volunteer developer(s) are not responsible for misuse of the app, for any present or future security vulnerabilities, or for any issues that may arise if the app is not updated when updates are provided. If you do not agree with these terms, please uninstall the app.
''';

  static const String _licensingText = '''
Licensing
The app is free to use for the IALFM community. Redistribution or commercial distribution is not permitted without IALFM’s written permission.
''';
}

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