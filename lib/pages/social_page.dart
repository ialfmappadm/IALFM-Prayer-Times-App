
// lib/pages/social_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemUiOverlayStyle
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import '../main.dart' show AppGradients;

// Cool Light palette anchors
const _kLightTextPrimary = Color(0xFF0F2432); // deep blue-gray
const _kLightTextMuted   = Color(0xFF4A6273);

class SocialPage extends StatelessWidget {
  const SocialPage({super.key});

  // IALFM destinations
  static const String _igHandle = 'ialfm_masjid';
  static final Uri _igAppUri = Uri.parse('instagram://user?username=$_igHandle');
  static final Uri _igWebUri = Uri.parse('https://www.instagram.com/$_igHandle/');

  static const String _fbUser = 'ialfmmasjid';
  static final Uri _fbWebUri = Uri.parse('https://www.facebook.com/$_fbUser');
  static final Uri _fbAppUri =
  Uri.parse('fb://facewebmodal/f?href=https://www.facebook.com/$_fbUser');

  Future<void> _openInstagram(BuildContext context) async {
    final ok = await _tryLaunch(_igAppUri);
    if (!ok) {
      final okWeb = await _tryLaunch(_igWebUri);
      if (!okWeb) _toast(context, 'Could not open Instagram');
    }
  }

  Future<void> _openFacebook(BuildContext context) async {
    final ok = await _tryLaunch(_fbAppUri);
    if (!ok) {
      final okWeb = await _tryLaunch(_fbWebUri);
      if (!okWeb) _toast(context, 'Could not open Facebook');
    }
  }

  Future<bool> _tryLaunch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Theme-adaptive gradient with Light fallback if extension missing
    final gradient = Theme.of(context).extension<AppGradients>()?.page ??
        (isLight
            ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF6F9FC), Colors.white],
        )
            : AppColors.pageGradient);

    // AppBar per theme
    final appBarBg   = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? _kLightTextPrimary : Colors.white;
    final iconsColor = titleColor;
    final overlay    = isLight ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;

    // Icon/text colors per theme (request: dark icons in Light, white in Dark)
    final socialIconColor  = isLight ? _kLightTextPrimary : Colors.white;
    final primaryTextColor = socialIconColor;
    final secondaryText    = isLight ? _kLightTextMuted : Colors.white.withValues(alpha: 0.75);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Follow Us…',
          style: TextStyle(
            color: titleColor,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: iconsColor),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Instagram
                  InkWell(
                    onTap: () => _openInstagram(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      child: Column(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.instagram,
                            size: 96,
                            color: socialIconColor, // <- dark in Light, white in Dark
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '@$_igHandle',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'instagram.com/$_igHandle',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Facebook
                  InkWell(
                    onTap: () => _openFacebook(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      child: Column(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.facebookF,
                            size: 80,
                            color: socialIconColor, // <- dark in Light, white in Dark
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '@$_fbUser',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'facebook.com/$_fbUser',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
