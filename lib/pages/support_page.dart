
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart' show AppGradients;
import '../app_colors.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  static const _feedback = 'ialfm.app.adm@gmail.com';
  static const _board = 'bod@ialfm.org';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final gradients = theme.extension<AppGradients>();

    final appBarBg = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? const Color(0xFF0F2432) : Colors.white;
    final iconsColor = titleColor;
    final overlay = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text('Support', style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: iconsColor),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradients?.page),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _emailTile(context, _feedback, 'Feedback & Features'),
              const SizedBox(height: 12),
              _emailTile(context, _board, 'Governance / Board'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailTile(BuildContext context, String email, String caption) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(cs.primary.withValues(alpha: 0.05), cs.surface),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          const FaIcon(FontAwesomeIcons.envelope, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(caption, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8), fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: email));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copied')));
              }
            },
            icon: const FaIcon(FontAwesomeIcons.copy, size: 14),
            color: cs.onSurface,
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Email',
            onPressed: () async {
              final uri = Uri.parse('mailto:$email');
              try {
                final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email app')));
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email app')));
                }
              }
            },
            icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 14),
            color: cs.onSurface,
          ),
        ],
      ),
    );
  }
}