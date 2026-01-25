
// lib/pages/more_page.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../app_colors.dart';
import '../theme_controller.dart';
import 'settings_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // keeps the app-wide gradient
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Page title
              const Text(
                'More',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // Card with actions
              _Card(
                child: Column(
                  children: [
                    // Settings row (gear) ➜ opens Settings page
                    _RowTile(
                      leading: const FaIcon(
                        FontAwesomeIcons.gear,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                      label: 'Settings',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsPage()),
                        );
                      },
                    ),
                    _DividerThin(),

                    // Theme quick toggle (Light/Dark) — long-press to reset to System
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: ThemeController.themeMode,
                      builder: (context, mode, _) {
                        final isDark = mode == ThemeMode.dark;
                        final icon = isDark
                            ? FontAwesomeIcons.moon
                            : FontAwesomeIcons.solidSun;
                        final label = 'Dark Mode';

                        return _RowTile(
                          leading: FaIcon(
                            icon,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                          label: label,
                          trailing: Switch(
                            value: isDark,
                            onChanged: (v) {
                              ThemeController.setThemeMode(
                                  v ? ThemeMode.dark : ThemeMode.light);
                            },
                          ),
                          onTap: () {
                            ThemeController.setThemeMode(
                                isDark ? ThemeMode.light : ThemeMode.dark);
                          },
                          // Pro tip: long-press to go back to System theme
                          onLongPress: () {
                            ThemeController.setThemeMode(ThemeMode.system);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Theme reset to System'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Placeholder for future items (e.g., About, Feedback, Privacy)
              // _Card(child: ...)
            ],
          ),
        ),
      ),
    );
  }
}

// --- Small, reusable UI pieces (match your Directory styling) ---

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

class _RowTile extends StatelessWidget {
  final Widget leading;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _RowTile({
    super.key,
    required this.leading,
    required this.label,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            leading,
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
            if (trailing != null)
              trailing!
            else
              const FaIcon(
                FontAwesomeIcons.chevronRight,
                size: 14,
                color: AppColors.textPrimary,
              ),
          ],
        ),
      ),
    );
  }
}