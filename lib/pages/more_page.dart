
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../main.dart' show AppGradients;
import '../app_colors.dart';
import '../theme_controller.dart';

import 'about_page.dart';
import 'privacy_policy_page.dart';
import 'support_page.dart';

class MorePage extends StatefulWidget {
  const MorePage({super.key});
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  // ----- Preview-only state (no persistence yet) -----
  // Accessibility
  bool reduceAnimations = false;
  String textSize = 'Default'; // Small / Default / Large
  bool highContrast = false;

  // Notifications (preview only)
  bool adhan = false;
  bool iqamah = false;
  bool jumuah = false;

  // Prayer & Time
  bool countdown = true;
  String clockFormat = '12‑Hour'; // 12‑Hour / 24‑Hour

  // Language & Hijri
  String language = 'English'; // English / العربية
  int hijriUserOffset = 0;     // -1, 0, +1

  // App Behavior
  String defaultTab = 'Prayer'; // Prayer / Announcements / Social / Directory / More
  bool keepScreenAwake = false;
  bool haptics = true;

  // Data & Storage
  String lastSync = '—';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final gradients = theme.extension<AppGradients>();

    // Match Social/Directory header
    final appBarBg = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? const Color(0xFF0F2432) : Colors.white;
    final iconsColor = titleColor;
    final overlay = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text('More', style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: iconsColor),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradients?.page),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              // ============= ACCESSIBILITY =============
              _sectionHeader(context, 'Accessibility'),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    initiallyExpanded: true,
                    leading: _secIcon(FontAwesomeIcons.universalAccess),
                    title: _secTitle(context, 'Accessibility'),
                    children: [
                      // Dark Mode (driven by ThemeController)
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
                              ThemeController.setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
                              HapticFeedback.lightImpact();
                            },
                          );
                        },
                      ),
                      const _Hairline(),
                      _switchRow(
                        context: context,
                        icon: FontAwesomeIcons.wandMagicSparkles,
                        label: 'Reduce Animations',
                        value: reduceAnimations,
                        onChanged: (v) {
                          setState(() => reduceAnimations = v);
                          _toast('Preview: Reduce animations ${v ? 'on' : 'off'}');
                        },
                      ),
                      const _Hairline(),
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
                      const _Hairline(),
                      _switchRow(
                        context: context,
                        icon: FontAwesomeIcons.highlighter,
                        label: 'High Contrast',
                        value: highContrast,
                        onChanged: (v) {
                          setState(() => highContrast = v);
                          _toast('Preview: High contrast ${v ? 'on' : 'off'}');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= NOTIFICATIONS (preview only) =============
              _sectionHeader(context, 'Notifications'),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
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
                      const _Hairline(),
                      _switchRow(
                        context: context,
                        icon: FontAwesomeIcons.circlePlay,
                        label: 'Daily Adhan Alerts',
                        value: adhan,
                        onChanged: (v) {
                          setState(() => adhan = v);
                          _toast('Preview: Adhan alerts ${v ? 'enabled' : 'disabled'}');
                        },
                      ),
                      const _Hairline(),
                      _switchRow(
                        context: context,
                        icon: FontAwesomeIcons.personPraying,
                        label: 'Daily Iqamah Alerts',
                        value: iqamah,
                        onChanged: (v) {
                          setState(() => iqamah = v);
                          _toast('Preview: Iqamah alerts ${v ? 'enabled' : 'disabled'}');
                        },
                      ),
                      const _Hairline(),
                      _switchRow(
                        context: context,
                        icon: FontAwesomeIcons.mosque,
                        label: 'Jumu‘ah Reminder',
                        value: jumuah,
                        onChanged: (v) {
                          setState(() => jumuah = v);
                          _toast('Preview: Jumu‘ah reminder ${v ? 'enabled' : 'disabled'}');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= PRAYER & TIME =============
              _sectionHeader(context, 'Prayer & Time'),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    leading: _secIcon(FontAwesomeIcons.clock),
                    title: _secTitle(context, 'Prayer & Time'),
                    children: [
                      _switchRow(
                        context: context,
                        icon: FontAwesomeIcons.hourglassHalf,
                        label: 'Countdown to Next Prayer',
                        value: countdown,
                        onChanged: (v) {
                          setState(() => countdown = v);
                          _toast('Preview: Countdown ${v ? 'on' : 'off'}');
                        },
                      ),
                      const _Hairline(),
                      _segmentedRow(
                        context: context,
                        icon: FontAwesomeIcons.clock,
                        label: 'Time Format',
                        segments: const ['12‑Hour', '24‑Hour'],
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

              // ============= LANGUAGE & HIJRI =============
              _sectionHeader(context, 'Language & Hijri'),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    leading: _secIcon(FontAwesomeIcons.language),
                    title: _secTitle(context, 'Language & Hijri'),
                    children: [
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.language,
                        label: 'Language',
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
                          _toast('Preview: Language = $choice');
                        },
                      ),
                      const _Hairline(),
                      _segmentedRow(
                        context: context,
                        icon: FontAwesomeIcons.calendarDay,
                        label: 'Hijri Date Adjustment',
                        segments: const ['−1', '0', '+1'],
                        index: hijriUserOffset + 1,
                        onChanged: (i) {
                          final val = i - 1;
                          setState(() => hijriUserOffset = val);
                          _toast('Preview: Hijri offset ${val >= 0 ? '+$val' : '$val'}');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= APP BEHAVIOR =============
              _sectionHeader(context, 'App Behavior'),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    leading: _secIcon(FontAwesomeIcons.gear),
                    title: _secTitle(context, 'App Behavior'),
                    children: [
                      _pickerRow(
                        context: context,
                        icon: FontAwesomeIcons.house,
                        label: 'Default Home Tab',
                        value: defaultTab,
                        onTap: () async {
                          final choice = await _chooseOne(
                            context,
                            title: 'Default Home Tab',
                            options: const ['Prayer', 'Announcements', 'Social', 'Directory', 'More'],
                            selected: defaultTab,
                          );
                          if (choice == null) return;
                          setState(() => defaultTab = choice);
                          _toast('Preview: Default tab = $choice');
                        },
                      ),
                      const _Hairline(),
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
                      _switchRow(
                        context: context,
                        icon: FontAwesomeIcons.lock,
                        label: 'Keep Screen Awake (Prayer Page)',
                        value: keepScreenAwake,
                        onChanged: (v) {
                          setState(() => keepScreenAwake = v);
                          _toast('Preview: Keep screen awake ${v ? 'on' : 'off'}');
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ============= DATA & STORAGE =============
              _sectionHeader(context, 'Data & Storage'),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
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
                      _buttonRow(
                        context: context,
                        icon: FontAwesomeIcons.trashCan,
                        label: 'Clear Cached Data',
                        onPressed: () {
                          _toast('Preview: Cache cleared');
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

              // ============= ABOUT & LEGAL =============
              _sectionHeader(context, 'About & Legal'),
              _card(context, child: Column(children: [
                _navRow(
                  context: context,
                  icon: FontAwesomeIcons.circleInfo,
                  label: 'About',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutPage())),
                ),
                const _Hairline(),
                _navRow(
                  context: context,
                  icon: FontAwesomeIcons.shieldHalved,
                  label: 'Privacy Policy',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
                ),
                const _Hairline(),
                _navRow(
                  context: context,
                  icon: FontAwesomeIcons.envelope,
                  label: 'Support',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportPage())),
                ),
              ])),
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
        style: const TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.4),
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? Color.alphaBlend(const Color(0xFF0A2C42).withValues(alpha: 0.25), Colors.black)
        : Color.alphaBlend(cs.primary.withValues(alpha: 0.05), cs.surface);
    final hairline = isDark ? Colors.white.withValues(alpha: 0.08) : cs.outline.withValues(alpha: 0.30);

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
          Switch(value: value, onChanged: onChanged),
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

  // <-- Missing before: now included -->
  Widget _navRow({
    required BuildContext context,
    required IconData icon,
    required String label,
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
            FaIcon(FontAwesomeIcons.chevronRight, size: 14, color: cs.onSurface),
          ],
        ),
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