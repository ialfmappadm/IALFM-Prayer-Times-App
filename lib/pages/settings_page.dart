
// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../app_colors.dart';
import '../theme_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Settings',
          style: TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            // THEME
            const Text(
              'Appearance',
              style: TextStyle(
                color: Color(0xFFC9A23F), // gold
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            _Card(
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.themeMode,
                builder: (context, mode, _) {
                  return Column(
                    children: [
                      _RadioRow(
                        icon: FontAwesomeIcons.mobileScreen,
                        label: 'System Default',
                        selected: mode == ThemeMode.system,
                        onTap: () => ThemeController.setThemeMode(ThemeMode.system),
                      ),
                      _DividerThin(),
                      _RadioRow(
                        icon: FontAwesomeIcons.solidSun,
                        label: 'Light',
                        selected: mode == ThemeMode.light,
                        onTap: () => ThemeController.setThemeMode(ThemeMode.light),
                      ),
                      _DividerThin(),
                      _RadioRow(
                        icon: FontAwesomeIcons.moon,
                        label: 'Dark',
                        selected: mode == ThemeMode.dark,
                        onTap: () => ThemeController.setThemeMode(ThemeMode.dark),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Add more setting groups here (Notifications, Data, About, etc.)
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPrimary.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }
}

class _DividerThin extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    color: Colors.white.withOpacity(0.08),
    indent: 14,
    endIndent: 14,
  );
}

class _RadioRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadioRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            FaIcon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFFC9A23F)
                      : Colors.white.withOpacity(0.6),
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFC9A23F),
                  ),
                ),
              )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}