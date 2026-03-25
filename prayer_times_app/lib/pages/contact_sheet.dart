// lib/widgets/contact_sheet.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _gold = Color(0xFFC7A447);

Future<void> showContactSheet(BuildContext context) async {
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
                onTap: () => _launchMail('ialfm.app.adm@gmail.com', context),
              ),
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Board / Governance'),
                subtitle: const Text('bod@ialfm.org'),
                onTap: () => _launchMail('bod@ialfm.org', context),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
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

Future<void> _launchMail(String to, BuildContext context) async {
  final uri = Uri.parse('mailto:$to');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!context.mounted) return;
  if (!ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open email app for $to')),
    );
  }
}