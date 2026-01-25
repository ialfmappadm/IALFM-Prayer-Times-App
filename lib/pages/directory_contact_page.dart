
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_colors.dart';

class DirectoryContactPage extends StatelessWidget {
  const DirectoryContactPage({super.key});

  // === EDIT THESE TO YOUR REAL CONTACT INFO ===
  static const String _displayPhone = '972-355-3937';
  static final Uri _telUri   = Uri.parse('tel:+19723553937');
  static final Uri _webUri   = Uri.parse('https://www.ialfm.org');
  static final Uri _mailUri  = Uri.parse('mailto:info@ialfm.org');
  // =============================================

  Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _row({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            FaIcon(icon, color: AppColors.textPrimary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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

  Divider _divider() => Divider(
    height: 1,
    color: Colors.white.withOpacity(0.08),
    indent: 14,
    endIndent: 14,
  );

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Contact Us',
          style: TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _row(
                        icon: FontAwesomeIcons.phone,
                        label: _displayPhone,
                        onTap: () async {
                          final ok = await _open(_telUri);
                          if (!ok) _toast(context, 'Could not start call');
                        },
                      ),
                      _divider(),
                      _row(
                        icon: FontAwesomeIcons.globe,
                        label: _webUri.toString().replaceFirst('https://', ''),
                        onTap: () async {
                          final ok = await _open(_webUri);
                          if (!ok) _toast(context, 'Could not open website');
                        },
                      ),
                      _divider(),
                      _row(
                        icon: FontAwesomeIcons.envelope,
                        label: _mailUri.path,
                        onTap: () async {
                          final ok = await _open(_mailUri);
                          if (!ok) _toast(context, 'Could not open email');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}