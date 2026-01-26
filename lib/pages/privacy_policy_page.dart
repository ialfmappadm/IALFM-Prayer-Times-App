
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show AppGradients;
import '../app_colors.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: Text('Privacy Policy', style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.w600)),
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
                _bullet(context, 'We do not collect personal CPNI or sensitive personal data.'),
                _bullet(context, 'We may store non‑identifying app settings on your device (e.g., theme, language, Hijri offset).'),
                _bullet(context, 'Push notifications are used solely to deliver masjid announcements and time‑sensitive updates. You can manage notifications in your device Settings.'),
                _bullet(context, 'We do not sell or share personal data with third parties.'),
              ],
            ),
          ),
        ),
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
          const Text('•  ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: TextStyle(color: cs.onSurface, height: 1.35, fontSize: 15))),
        ],
      ),
    );
  }
}