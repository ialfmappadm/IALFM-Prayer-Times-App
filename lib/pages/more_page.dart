
// lib/pages/more_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../main.dart' show AppGradients;
import '../app_colors.dart';
import '../theme_controller.dart';
import '../locale_controller.dart';

// Generated localizations (requires l10n.yaml + app_en.arb + app_ar.arb)
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';

class MorePage extends StatefulWidget {
  const MorePage({super.key});
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  // Preview-only state (not persisted)
  String textSize = 'Default';             // 'Small' | 'Default' | 'Large'
  String clockFormat = '12‑Hour';          // '12‑Hour' | '24‑Hour'
  String lastSync = '—';
  bool haptics = true;

  // Collapsed by default
  bool _accExpanded = false;
  bool _notifExpanded = false;
  bool _timeExpanded = false;
  bool _langExpanded = false;
  bool _dataExpanded = false;

  // Reflect current locale to a human label for the row
  String _currentLanguageLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final code = LocaleController.locale.value?.languageCode;
    return (code == 'ar') ? l10n.lang_arabic : l10n.lang_english;
  }

  // Apply language choice -> update LocaleController; UI reads it directly
  void _applyLanguageChoice(String choice, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (choice == l10n.lang_arabic) {
      LocaleController.setLocale(const Locale('ar'));
    } else {
      LocaleController.setLocale(const Locale('en'));
    }
    // No local 'language' field, so nothing to desync.
  }

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final isLight   = theme.brightness == Brightness.light;
    final gradients = theme.extension<AppGradients>();
    final l10n      = AppLocalizations.of(context)!;

    final appBarBg   = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? const Color(0xFF0F2432) : Colors.white;
    final overlay    = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text(l10n.tab_more, style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: titleColor),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradients?.page ?? AppColors.pageGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              // ============= ACCESSIBILITY =============
              _sectionHeader(context, l10n.more_accessibility),
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
                    title: _secTitle(context, l10n.more_accessibility),
                    children: [
                      // Dark mode (binds to ThemeController)
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeController.themeMode,
                        builder: (context, mode, _) {
                          final isDark = mode == ThemeMode.dark;
                          return _switchRow(
                            context: context,
                            icon: FontAwesomeIcons.moon,
                            label: l10n.more_dark_mode,
                            value: isDark,
                            onChanged: (v) {
                              ThemeController.setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
                              HapticFeedback.lightImpact();
                            },
                          );
                        },
                      ),
                      const _Hairline(),
                      // Haptics (moved from App Behavior)
                      _switchRow(
                        context: context,
                        icon: FontAwesomeIcons.mobileScreenButton,
                        label: l10n.more_haptics,
                        value: haptics,
                        onChanged: (v) {
                          setState(() => haptics = v);
                          HapticFeedback.lightImpact();
                        },
                      ),
                      const _Hairline(),
                      // Text Size picker (preview only)
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.textHeight,
                        label: l10n.more_text_size,
                        value: textSize,
                        onTap: () async {
                          final choice = await _chooseOne(
                            context,
                            title: l10n.more_text_size,
                            options: const <String>['Small', 'Default', 'Large'],
                            selected: textSize,
                          );
                          if (choice == null) return;
                          setState(() => textSize = choice);
                          _toast('Preview: Text size = $choice');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= NOTIFICATIONS (preview only) =============
              _sectionHeader(context, l10n.more_notifications),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: _notifExpanded,
                    onExpansionChanged: (v) => setState(() => _notifExpanded = v),
                    leading: _secIcon(FontAwesomeIcons.bell),
                    title: _secTitle(context, l10n.more_notifications),
                    children: [
                      _buttonRow(
                        context: context,
                        icon: FontAwesomeIcons.bell,
                        label: l10n.more_enable_notifications,
                        onPressed: () => _toast('Preview: would request OS permission or open Settings'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= TIME (keep Time Format only) =============
              _sectionHeader(context, l10n.more_time),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: _timeExpanded,
                    onExpansionChanged: (v) => setState(() => _timeExpanded = v),
                    leading: _secIcon(FontAwesomeIcons.clock),
                    title: _secTitle(context, l10n.more_time),
                    children: [
                      _segmentedRow(
                        context: context,
                        icon: FontAwesomeIcons.clock,
                        label: l10n.more_time_format,
                        segments: const <String>['12‑Hour', '24‑Hour'],
                        index: clockFormat == '12‑Hour' ? 0 : 1,
                        onChanged: (i) {
                          setState(() => clockFormat = i == 0 ? '12‑Hour' : '24‑Hour');
                          _toast('Preview: Time format = $clockFormat');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= LANGUAGE =============
              _sectionHeader(context, l10n.more_language),
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
                    title: _secTitle(context, l10n.more_language),
                    children: [
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.language,
                        label: l10n.more_language_label,
                        value: _currentLanguageLabel(context), // reads LocaleController
                        onTap: () async {
                          final List<String> options = <String>[l10n.lang_english, l10n.lang_arabic];
                          final selectedNow = _currentLanguageLabel(context);
                          final choice = await _chooseOne(
                            context,
                            title: l10n.more_language,
                            options: options,          // typed list avoids List<dynamic> inference
                            selected: selectedNow,
                          );
                          if (choice == null) return;
                          _applyLanguageChoice(choice, context);
                          _toast('${l10n.more_language}: $choice');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= DATA & STORAGE =============
              _sectionHeader(context, l10n.more_data_storage),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: _dataExpanded,
                    onExpansionChanged: (v) => setState(() => _dataExpanded = v),
                    leading: _secIcon(FontAwesomeIcons.database),
                    title: _secTitle(context, l10n.more_data_storage),
                    children: [
                      _buttonRow(
                        context: context,
                        icon: FontAwesomeIcons.rotate,
                        label: l10n.more_refresh_data,
                        onPressed: () async {
                          setState(() => lastSync = TimeOfDay.now().format(context));
                          _toast('Preview: Data refreshed');
                        },
                      ),
                      const _Hairline(),
                      _staticRow(
                        context: context,
                        icon: FontAwesomeIcons.circleInfo,
                        label: l10n.more_last_sync,
                        trailing: Text(lastSync),
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

  // ---------- Shared UI helpers ----------

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
    final theme  = Theme.of(context);
    final cs     = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? Color.alphaBlend(AppColors.bgPrimary.withValues(alpha: 0.25), Colors.black)
        : Color.alphaBlend(cs.primary.withValues(alpha: 0.05), cs.surface);
    final hairline =
    isDark ? Colors.white.withValues(alpha: 0.08) : cs.outline.withValues(alpha: 0.30);
    return Container(
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: hairline),
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

  Widget _pickerRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
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
            Text(value, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8))),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 14), // stays LTR
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
            segments: List.generate(segments.length, (i) => ButtonSegment(value: i, label: Text(segments[i]))),
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

  // Row with a trailing button (kept identical look; literal "Open" avoids new ARB keys)
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
            child: Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
          ),
          FilledButton.tonal(onPressed: onPressed, child: const Text('Open')),
        ],
      ),
    );
  }

  // Bottom sheet with state managed inside so radios update immediately
  Future<String?> _chooseOne(
      BuildContext context, {
        required String title,
        required List<String> options,
        required String selected,
      }) async {
    String temp = selected;

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final l10n = AppLocalizations.of(context)!;

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
                    for (final opt in options)
                      RadioListTile<String>(
                        value: opt,
                        groupValue: temp,
                        onChanged: (v) => setModalState(() => temp = v ?? selected),
                        title: Text(opt, style: TextStyle(color: cs.onSurface)),
                      ),
                    const SizedBox(height: 8),
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
                            onPressed: () => Navigator.pop(ctx, temp),
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
