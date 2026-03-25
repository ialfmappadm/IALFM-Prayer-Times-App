// lib/pages/privacy_policy_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';

import '../main.dart' show AppGradients;
import '../app_colors.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const String _policyUrl =
      'https://www.ialfm.org/ialfm-mobile-app-privacy-policy/';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final gradients = theme.extension<AppGradients>();
    final appBarBg = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? const Color(0xFF0F2432) : Colors.white;
    final overlay =
    isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.privacy_title,
          style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradients?.page),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(context, l10n.privacy_summary),
                const SizedBox(height: 8),
                _bullet(context, l10n.privacy_b1),
                _bullet(context, l10n.privacy_b2),
                _bullet(context, l10n.privacy_b3),
                _bullet(context, l10n.privacy_b4),
                _bullet(context, l10n.privacy_b5),
                _bullet(context, l10n.privacy_b6),
                _bullet(context, l10n.privacy_b7),
                _bullet(context, l10n.privacy_b8),
                _bullet(context, l10n.privacy_b9),
                _bullet(context, l10n.privacy_b10),

                const SizedBox(height: 20),
                _sectionHeader(context, l10n.privacy_view_full),
                const SizedBox(height: 8),
                Text(
                  l10n.privacy_view_full_hint,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85), height: 1.35),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openPolicyUrl(),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.open_full_policy_button),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC7A447), // gold
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openPolicyUrl() async {
    final uri = Uri.parse(_policyUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _sectionHeader(BuildContext context, String text) {
    const gold = Color(0xFFC7A447);
    return Text(
      text,
      style: const TextStyle(
        color: gold,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: cs.onSurface, height: 1.35, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}