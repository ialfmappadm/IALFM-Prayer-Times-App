
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../main.dart' show AppGradients;
import '../app_colors.dart';
import '../theme_controller.dart';      // your existing theme controller
import '../locale_controller.dart';     // <-- new

class MorePage extends StatefulWidget {
  const MorePage({super.key});
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  // Preview (non-persistent) items we've kept
  String textSize = 'Default';            // Small / Default / Large
  String clockFormat = '12‑Hour';         // 12‑Hour / 24‑Hour
  String language = 'English';            // English / العربية
  String lastSync = '—';

  // Moved to Accessibility
  bool haptics = true;

  // Collapsed state (start collapsed as requested)
  bool _accExpanded = false;
  bool _notifExpanded = false;
  bool _timeExpanded = false;
  bool _langExpanded = false;
  bool _dataExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme     = Theme.of(context);
    final isLight   = theme.brightness == Brightness.light;
    final gradients = theme.extension<AppGradients>();

    // Match Social/Directory/Contact header
    final appBarBg   = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? const Color(0xFF0F2432) : Colors.white;
    final overlay    = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text('More', style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: titleColor),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradients?.page ?? AppColors.pageGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              // ============= ACCESSIBILITY (collapsed by default) =============
              _sectionHeader(context, 'Accessibility'),
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
                    title: _secTitle(context, 'Accessibility'),
                    children: [
                      // Dark Mode — bind strictly to ThemeController to avoid first-toggle no-op
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeController.themeMode,
                        builder: (context, mode, _) {
                          final isDark = mode == ThemeMode.dark;
                          return _switchRow(
                            context: context,
                            icon: FontAwesomeIcons.moon,
                            label: 'Dark Mode',
                            value: isDark,
                            onChanged: (v) {
                              ThemeController.setThemeMode(
                                v ? ThemeMode.dark : ThemeMode.light,
                              );
                              HapticFeedback.lightImpact();
                            },
                          );
                        },
                      ),
                      const _Hairline(),

                      // Haptic Feedback (moved from App Behavior)
                      _switchRow(
                        context: context,
                        icon: FontAwesomeIcons.mobileScreenButton,
                        label: 'Haptic Feedback',
                        value: haptics,
                        onChanged: (v) {
                          setState(() => haptics = v);
                          HapticFeedback.lightImpact();
                        },
                      ),
                      const _Hairline(),

                      // Optional: keep Text Size (preview only)
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.textHeight,
                        label: 'Text Size',
                        value: textSize,
                        onTap: () async {
                          final choice = await _chooseOne(
                            context,
                            title: 'Text Size',
                            options: const ['Small', 'Default', 'Large'],
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

              // ============= NOTIFICATIONS (left intact; still collapsed) =============
              _sectionHeader(context, 'Notifications'),
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
                    title: _secTitle(context, 'Notifications'),
                    children: [
                      _buttonRow(
                        context: context,
                        icon: FontAwesomeIcons.bell,
                        label: 'Enable Notifications',
                        onPressed: () {
                          _toast('Preview: would request OS permission or open Settings');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= TIME (no Countdown; keep Time Format only) =============
              _sectionHeader(context, 'Time'),
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
                    title: _secTitle(context, 'Time'),
                    children: [
                      _segmentedRow(
                        context: context,
                        icon: FontAwesomeIcons.clock,
                        label: 'Time Format',
                        segments: const ['12‑Hour', '24‑Hour'],
                        index: clockFormat == '12‑Hour' ? 0 : 1,
                        onChanged: (i) {
                          setState(() => clockFormat = i == 0 ? '12‑Hour' : '24‑Hour');
                          _toast('Preview: Time format = $clockFormat');
                          // TODO: wire to your actual time-format controller
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= LANGUAGE (wire Arabic) =============
              _sectionHeader(context, 'Language'),
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
                    title: _secTitle(context, 'Language'),
                    children: [
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.language,
                        label: 'App Language',
                        value: language,
                        onTap: () async {
                          final choice = await _chooseOne(
                            context,
                            title: 'Language',
                            options: const ['English', 'العربية'],
                            selected: language,
                          );
                          if (choice == null) return;

                          setState(() => language = choice);

                          // Apply the locale
                          if (choice == 'العربية') {
                            LocaleController.setLocale(const Locale('ar'));
                          } else {
                            LocaleController.setLocale(const Locale('en'));
                          }
                          _toast('Language: $choice');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= DATA & STORAGE (kept; collapsed) =============
              _sectionHeader(context, 'Data & Storage'),
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
                    title: _secTitle(context, 'Data & Storage'),
                    children: [
                      _buttonRow(
                        context: context,
                        icon: FontAwesomeIcons.rotate,
                        label: 'Refresh Data Now',
                        onPressed: () async {
                          setState(() => lastSync = TimeOfDay.now().format(context));
                          _toast('Preview: Data refreshed');
                        },
                      ),
                      const _Hairline(),
                      _staticRow(
                        context: context,
                        icon: FontAwesomeIcons.circleInfo,
                        label: 'Last Sync',
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

  // ---------------- Shared UI helpers (identical look to Directory/More) ----------------

  Widget _sectionHeader(BuildContext context, String title) {
    const gold = Color(0xFFC7A447);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: gold,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? Color.alphaBlend(AppColors.bgPrimary.withValues(alpha: 0.25), Colors.black)
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
            FaIcon(FontAwesomeIcons.chevronRight, size: 14, color: cs.onSurface),
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
            segments: List.generate(segments.length, (i) =>
                ButtonSegment(value: i, label: Text(segments[i]))),
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
          Expanded(child: Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700))),
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
    String temp = selected;
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
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
                    onChanged: (v) => setState(() => temp = v ?? selected),
                    title: Text(opt, style: TextStyle(color: cs.onSurface)),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(onPressed: () => Navigator.pop(ctx, temp), child: const Text('Save'))),
                  ],
                ),
              ],
            ),
          ),
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