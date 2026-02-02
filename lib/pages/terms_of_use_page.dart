// lib/pages/terms_of_use_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';

import '../main.dart' show AppGradients;
import '../app_colors.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  static const _websiteUrl = 'https://www.ialfm.org';
  static const _policyUrl  = 'https://www.ialfm.org/ialfm-mobile-app-privacy-policy/';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final gradients = theme.extension<AppGradients>();
    final appBarBg = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? const Color(0xFF0F2432) : Colors.white;
    final overlay = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.more_terms_of_use,
          style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: titleColor),
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
                _sectionHeader(l10n.terms_agreement),
                const SizedBox(height: 8),
                _bodyText(context, l10n.terms_agreement_body),

                const SizedBox(height: 16),
                _sectionHeader(l10n.terms_acceptable_use),
                const SizedBox(height: 8),
                _bullet(context, l10n.terms_acceptable_b1),
                _bullet(context, l10n.terms_acceptable_b2),

                const SizedBox(height: 16),
                _sectionHeader(l10n.terms_content_links),
                const SizedBox(height: 8),
                _bullet(context, l10n.terms_links_b1),
                _bullet(context, l10n.terms_links_b2),

                const SizedBox(height: 16),
                _sectionHeader(l10n.terms_donations),
                const SizedBox(height: 8),
                _bullet(context, l10n.terms_donations_b1),

                const SizedBox(height: 16),
                _sectionHeader(l10n.terms_no_warranty),
                const SizedBox(height: 8),
                _bullet(context, l10n.terms_no_warranty_b1),
                _bullet(context, l10n.terms_no_warranty_b2),

                const SizedBox(height: 16),
                _sectionHeader(l10n.terms_liability),
                const SizedBox(height: 8),
                _bullet(context, l10n.terms_liability_b1),

                const SizedBox(height: 16),
                _sectionHeader(l10n.terms_ip),
                const SizedBox(height: 8),
                _bullet(context, l10n.terms_ip_b1),
                _bullet(context, l10n.terms_ip_b2),

                const SizedBox(height: 16),
                _sectionHeader(l10n.terms_privacy_header),
                const SizedBox(height: 8),
                _bodyText(context, l10n.terms_privacy_body),
                const SizedBox(height: 8),
                _linkButton(context, l10n.view_privacy_policy_website, _policyUrl),

                const SizedBox(height: 16),
                _sectionHeader(l10n.contact_title),
                const SizedBox(height: 8),
                _linkButton(context, l10n.contact_support, null, onTap: () => _showContactSheet(context)),
                const SizedBox(height: 10),
                _linkButton(context, l10n.about_visit_website, _websiteUrl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Private helpers ----
  static Future<void> _openExternal(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $url')),
      );
    }
  }

  static Future<void> _showContactSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
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
                Text(l10n.contact_title,
                    style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(Icons.feedback_outlined),
                  title: Text(l10n.contact_feedback_title),
                  subtitle: const Text('ialfm.app.adm@gmail.com'),
                  onTap: () => _launchMail('ialfm.app.adm@gmail.com', ctx),
                ),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: Text(l10n.contact_board_title),
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
                    child: Text(l10n.btn_close),
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
    final uri = Uri.parse('mailto:$to');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open email app for $to')),
      );
    }
  }

  Widget _sectionHeader(String title) {
    const gold = Color(0xFFC7A447);
    return Text(
      title,
      style: const TextStyle(
        color: gold,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _bodyText(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text.trim(),
      style: TextStyle(color: cs.onSurface, height: 1.35, fontSize: 15),
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

  Widget _linkButton(BuildContext context, String label, String? url, {VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap ?? () => _openExternal(url!, context),
        icon: const Icon(Icons.open_in_new),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFC7A447), // gold
          foregroundColor: Colors.black,
        ),
      ),
    );
  }
}