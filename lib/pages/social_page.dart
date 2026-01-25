
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for SystemUiOverlayStyle
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_colors.dart'; // adjust if your colors file is elsewhere

class SocialPage extends StatelessWidget {
  const SocialPage({super.key});

  // --- IALFM destinations ---
  static const String _igHandle = 'ialfm_masjid';
  static final Uri _igAppUri =
  Uri.parse('instagram://user?username=$_igHandle');
  static final Uri _igWebUri =
  Uri.parse('https://www.instagram.com/$_igHandle/');

  static const String _fbUser = 'ialfmmasjid';
  static final Uri _fbWebUri = Uri.parse('https://www.facebook.com/$_fbUser');
  static final Uri _fbAppUri =
  Uri.parse('fb://facewebmodal/f?href=https://www.facebook.com/$_fbUser');

  // --- Launch helpers ---
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
    const Color white = Colors.white;                 // icons/text on blue
    final Color whiteSubtle = Colors.white.withOpacity(0.75);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        // ✅ Blue (navy) background so the title shows clearly
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Follow Us...',
          style: TextStyle(
            color: white,            // ✅ white heading on blue
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: white),  // white back icon
        systemOverlayStyle: SystemUiOverlayStyle.light, // status bar icons light
      ),
      body: Container(
        // Same blue gradient as other pages
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- Instagram (white icon, centered) ---
                  InkWell(
                    onTap: () => _openInstagram(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      child: Column(
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.instagram,
                            size: 96,
                            color: white,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '@$_igHandle',
                            style: const TextStyle(
                              color: white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'instagram.com/$_igHandle',
                            style: TextStyle(
                              color: whiteSubtle,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // --- Facebook (white icon, centered) ---
                  InkWell(
                    onTap: () => _openFacebook(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      child: Column(
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.facebookF,
                            size: 80,
                            color: white,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '@$_fbUser',
                            style: const TextStyle(
                              color: white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'facebook.com/$_fbUser',
                            style: TextStyle(
                              color: whiteSubtle,
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