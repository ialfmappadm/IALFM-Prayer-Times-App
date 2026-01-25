
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';              // match Social's navy source
import '../main.dart' show AppGradients;   // theme extension for gradients

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

  // Local brand (for dark tint & CTA)
  static const _navy = Color(0xFF0A2C42);
  static const _gold = Color(0xFFC7A447);

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
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textColor = cs.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            FaIcon(icon, color: textColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            FaIcon(
              FontAwesomeIcons.chevronRight,
              size: 14,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }

  Divider _divider(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      color: isDark ? Colors.white.withOpacity(0.08) : cs.outline.withOpacity(0.30),
      indent: 14,
      endIndent: 14,
    );
  }

  Widget _mapPreview(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final image = Image.asset(
      _mapAsset,
      fit: BoxFit.cover,
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
              // Local map image (16:9)
              AspectRatio(aspectRatio: 16 / 9, child: image),
              // Bottom scrim with caption + CTA
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: _gold, // gold CTA (consistent in dark too)
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Padding(
                          padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            style: TextStyle(
              color: cs.onSurface,
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
          icon: FaIcon(
            FontAwesomeIcons.copy,
            size: 16,
            color: cs.onSurface,
          ),
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
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cs = theme.colorScheme;
    final gradients = theme.extension<AppGradients>();

    // === Match Social header exactly ===
    final appBarBg = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? const Color(0xFF0F2432) : Colors.white;
    final iconsColor = titleColor;
    final overlay =
    isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    // Subtle card fill under contact rows — navy glaze in dark
    final Color cardFill = isLight
        ? Color.alphaBlend(cs.primary.withOpacity(0.05), cs.surface)
        : Color.alphaBlend(AppColors.bgPrimary.withOpacity(0.25), Colors.black);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Contact Us',
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
        decoration: BoxDecoration(gradient: gradients?.page),
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
                        color: cardFill,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _row(
                            context: context,
                            icon: FontAwesomeIcons.phone,
                            label: _displayPhone,
                            onTap: () async {
                              final ok = await _open(_telUri);
                              if (!ok) _toast(context, 'Could not start call');
                            },
                          ),
                          _divider(context),
                          _row(
                            context: context,
                            icon: FontAwesomeIcons.globe,
                            label:
                            _webUri.toString().replaceFirst('https://', ''),
                            onTap: () async {
                              final ok = await _open(_webUri);
                              if (!ok) _toast(context, 'Could not open website');
                            },
                          ),
                          _divider(context),
                          _row(
                            context: context,
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
