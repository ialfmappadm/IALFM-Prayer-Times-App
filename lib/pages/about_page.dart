
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart' show AppGradients;
import '../app_colors.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
        title: Text('About', style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: iconsColor),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradients?.page),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionHeader('In‑App Disclaimer'),
                _bodyText(context, '''
Important announcements from IALFM may be delivered as notifications so you don’t miss urgent updates. OS‑level notification settings are controlled by the user; if you disable notifications at the system level, you can still read all announcements in the app’s Announcements tab.

Privacy: We do not collect personal CPNI or sensitive personal data. See our Privacy Policy in the app for details.

Support: ialfm.app.adm@gmail.com (feedback/features), bod@ialfm.org (governance).

Licensing: The app is free to use for the IALFM community. Redistribution or commercial distribution is not permitted without IALFM’s written permission.
'''),
                // Note: We intentionally removed the separate "platform policy" warning block.
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    const gold = Color(0xFFC7A447);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Text(title, style: const TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
    );
  }

  Widget _bodyText(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text.trim(),
      style: TextStyle(color: cs.onSurface, height: 1.35, fontSize: 15),
    );
  }
}
