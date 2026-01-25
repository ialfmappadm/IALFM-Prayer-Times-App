
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';

class DirectoryContactPage extends StatelessWidget {
  const DirectoryContactPage({super.key});

  // === CONTACT INFO ===
  static const String _displayPhone = '972-355-3937';
  static final Uri _telUri = Uri.parse('tel:+19723553937');
  static final Uri _webUri = Uri.parse('https://www.ialfm.org');
  static final Uri _mailUri = Uri.parse('mailto:info@ialfm.org');

  // === LOCATION ===
  static const String _address =
      '3430 Peters Colony Rd., Flower Mound, TX 75022';
  static final Uri _mapsUri = Uri.parse(
      'https://maps.google.com/?q=3430+Peters+Colony+Rd.,+Flower+Mound,+TX+75022');

  // === YOUR LOCAL MAP IMAGE ===
  static const String _mapAsset = 'assets/images/ialfm_map_preview_16x9.jpg';

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
                maxLines: 2,
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

  Widget _mapPreview(BuildContext context) {
    final image = Image.asset(
      _mapAsset,
      fit: BoxFit.cover,
      // Optional hint: if your file is ~632px wide, uncomment below.
      // cacheWidth: 632,
      errorBuilder: (c, _, __) => _MapPlaceholder(onTap: () async {
        final ok = await _open(_mapsUri);
        if (!ok && c.mounted) {
          ScaffoldMessenger.of(c).showSnackBar(
            const SnackBar(content: Text('Could not open Maps')),
          );
        }
      }),
    );

    final mapCard = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final ok = await _open(_mapsUri);
          if (!ok && context.mounted) _toast(context, 'Could not open Maps');
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Local map image (16:9). Your screenshot already has a red pin,
              // so we do NOT add an overlay pin to avoid duplicates.
              AspectRatio(aspectRatio: 16 / 9, child: image),

              // Bottom scrim with caption + CTA
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x44000000),
                        Color(0x66000000),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(FontAwesomeIcons.locationDot,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFC9A23F), // Gold accent
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              FaIcon(FontAwesomeIcons.route,
                                  size: 12, color: Colors.black),
                              SizedBox(width: 6),
                              Text(
                                'Open in Maps',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
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
            ],
          ),
        ),
      ),
    );

    // Address line below the image + copy affordance
    final addressLine = Row(
      children: [
        Expanded(
          child: Text(
            _address,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copy address',
          onPressed: () async {
            await Clipboard.setData(const ClipboardData(text: _address));
            if (context.mounted) _toast(context, 'Address copied');
          },
          icon: const FaIcon(FontAwesomeIcons.copy,
              size: 16, color: AppColors.textPrimary),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        mapCard,
        const SizedBox(height: 12),
        addressLine,
      ],
    );
  }

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
          style:
          TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- CONTACT CARD (top) ---
                    Container(
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
                            label:
                            _webUri.toString().replaceFirst('https://', ''),
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

                    const SizedBox(height: 24),

                    // --- MAP PREVIEW (bottom) ---
                    _mapPreview(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Simple placeholder if the asset isn't found
class _MapPlaceholder extends StatelessWidget {
  final VoidCallback onTap;
  const _MapPlaceholder({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: Colors.white.withOpacity(0.06),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              FaIcon(FontAwesomeIcons.map, size: 26, color: Colors.white70),
              SizedBox(height: 8),
              Text(
                'Map preview unavailable (asset not found)',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}