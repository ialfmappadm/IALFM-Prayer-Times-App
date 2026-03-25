// lib/pages/social_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
// Match More/Directory theme
import '../app_colors.dart';
import '../main.dart' show AppGradients;
// NEW: generated localizations
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';

/// ===============================
/// CONFIG
/// ===============================
/// Layout:
/// 'cards' -> one logo per row (recommended for readability)
/// 'grid'  -> two-up grid for the two Instagrams; Facebook full width below
const _layout = 'cards';

/// Fixed glyph size (applies to IG + FB so they look uniform)
const double _iconSize = 72.0;

/// Card styling (lowerCamelCase to satisfy lints)
const double _cardRadius = 16.0;
const double _cardHPadding = 24.0;
const double _cardVPadding = 16.0;

/// Light palette anchors (used only for the AppBar title in light mode)
const _kLightTextPrimary = Color(0xFF0F2432);
const _kLightTextMuted   = Color(0xFF4A6273);

class SocialPage extends StatelessWidget {
  const SocialPage({super.key});

  // ========= Accounts =========
  // IALFM Instagram
  static const String _igHandle = 'ialfm_masjid';
  static final Uri _igAppUri = Uri.parse('instagram://user?username=$_igHandle');
  static final Uri _igWebUri = Uri.parse('https://www.instagram.com/$_igHandle/');

  // IALFM Youth Instagram
  static const String _igYouthHandle = 'ialfmyouth';
  static final Uri _igYouthAppUri = Uri.parse('instagram://user?username=$_igYouthHandle');
  static final Uri _igYouthWebUri = Uri.parse('https://www.instagram.com/$_igYouthHandle/');

  // Facebook
  static const String _fbUser = 'ialfmmasjid';
  static final Uri _fbWebUri = Uri.parse('https://www.facebook.com/$_fbUser');
  static final Uri _fbAppUri =
  Uri.parse('fb://facewebmodal/f?href=https://www.facebook.com/$_fbUser');

  // ========= SVG asset paths =========
  static const String _igSvg = 'assets/branding/instagram.svg';
  static const String _fbSvg = 'assets/branding/facebook.svg';

  @override
  Widget build(BuildContext context) {
    final l10n   = AppLocalizations.of(context); // <-- localized strings
    final theme  = Theme.of(context);
    final isLight= theme.brightness == Brightness.light;
    final cs     = theme.colorScheme;

    // Page gradient: prefer AppGradients (same as More/Directory), otherwise AppColors fallback.
    final pageGradient = theme.extension<AppGradients>()?.page ?? AppColors.pageGradient;

    // AppBar consistent with other pages
    final appBarBg   = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? _kLightTextPrimary : Colors.white;
    final overlay    = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    // Text colors inside cards (match other pages)
    final titleText = cs.onSurface;
    final subText   = isLight ? _kLightTextMuted : Colors.white.withValues(alpha: 0.75);

    final items = <_SocialItem>[
      _SocialItem(
        networkLabel: 'Instagram',
        handle: '@$_igHandle',
        urlText: 'instagram.com/$_igHandle',
        appUri: _igAppUri,
        webUri: _igWebUri,
        svgAsset: _igSvg,
      ),
      _SocialItem(
        networkLabel: 'Instagram',
        handle: '@$_igYouthHandle',
        urlText: 'instagram.com/$_igYouthHandle',
        appUri: _igYouthAppUri,
        webUri: _igYouthWebUri,
        svgAsset: _igSvg,
      ),
      _SocialItem(
        networkLabel: 'Facebook',
        handle: '@$_fbUser',
        urlText: 'facebook.com/$_fbUser',
        appUri: _fbAppUri,
        webUri: _fbWebUri,
        svgAsset: _fbSvg,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.social_follow_us, // <-- localized header
          style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: titleColor),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: pageGradient),
        child: SafeArea(
          child: _buildBody(context, items, titleText, subText),
        ),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context,
      List<_SocialItem> items,
      Color titleText,
      Color subText,
      ) {
    if (_layout == 'grid') {
      // Two-up IG, Facebook full width below
      final ig = items.where((e) => e.networkLabel == 'Instagram').toList();
      final fb = items.firstWhere((e) => e.networkLabel == 'Facebook');

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (ctx, c) {
                final w = (c.maxWidth - 14) / 2;
                return Row(
                  children: [
                    Expanded(child: _CardTile(item: ig[0], titleText: titleText, subText: subText, width: w)),
                    const SizedBox(width: 14),
                    Expanded(child: _CardTile(item: ig[1], titleText: titleText, subText: subText, width: w)),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _CardTile(item: fb, titleText: titleText, subText: subText),
          ],
        ),
      );
    }

    // 'cards' → one per row
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => _CardTile(
        item: items[i],
        titleText: titleText,
        subText: subText,
      ),
    );
  }
}

/// =============== Model ===============
class _SocialItem {
  _SocialItem({
    required this.networkLabel,
    required this.handle,
    required this.urlText,
    required this.appUri,
    required this.webUri,
    required this.svgAsset,
  });

  final String networkLabel; // Instagram / Facebook
  final String handle;
  final String urlText;
  final Uri appUri;
  final Uri webUri;
  final String svgAsset;
}

/// =============== Tile (bubble glaze + hairline like More/Directory) ===============
class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.item,
    required this.titleText,
    required this.subText,
    this.width,
  });

  final _SocialItem item;
  final Color titleText;
  final Color subText;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final cs     = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 🔹 CHANGE HERE:
    // Use the same DARK highlight color as Salah table rows for card background.
    // Light stays as-is.
    final bg = isDark
        ? AppColors.rowHighlight
        : Color.alphaBlend(cs.primary.withValues(alpha: 0.05), cs.surface);

    // Hairline identical to other pages
    final brd = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : cs.outline.withValues(alpha: 0.30);

    return InkWell(
      borderRadius: BorderRadius.circular(_cardRadius),
      onTap: () async {
        final okApp = await _tryLaunch(item.appUri);
        if (!okApp) {
          final okWeb = await _tryLaunch(item.webUri);
          if (!okWeb && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open ${item.networkLabel}')),
            );
          }
        }
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(
          horizontal: _cardHPadding,
          vertical: _cardVPadding,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: brd),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          children: [
            // Pure SVG glyph — no ring; exact same size for all networks
            SizedBox(
              width: _iconSize,
              height: _iconSize,
              child: SvgPicture.asset(
                item.svgAsset,
                width: _iconSize,
                height: _iconSize,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 10),
            // Handle (single line; ellipsis)
            Text(
              item.handle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: titleText, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            // URL (single line; ellipsis)
            Text(
              item.urlText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: subText),
            ),
          ],
        ),
      ),
    );
  }
}

/// =============== Launch helper (no BuildContext here) ===============
Future<bool> _tryLaunch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}