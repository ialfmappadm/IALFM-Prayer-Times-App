// lib/pages/membership_section.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';

/// A self-contained card section for Member Services (Membership).
/// Opens links in an in‑app browser (Safari View Controller / Custom Tabs).
class MembershipSectionCard extends StatefulWidget {
  const MembershipSectionCard({
    super.key,
    required this.mIndiv,
    required this.mFamily,
    required this.mRenew,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  final Uri mIndiv;
  final Uri mFamily;
  final Uri mRenew;

  /// Whether the ExpansionTile starts opened.
  final bool initiallyExpanded;

  /// Optional callback so the parent page can mirror/remember the expand state.
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<MembershipSectionCard> createState() => _MembershipSectionCardState();
}

class _MembershipSectionCardState extends State<MembershipSectionCard> {
  // ---- Visual tuning: matches DirectoryPage look & feel ----
  static const VisualDensity _kTileDensity =
  VisualDensity(horizontal: -1, vertical: -1.25);
  static const VisualDensity _kRowDensity =
  VisualDensity(horizontal: -1, vertical: -0.5);

  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  // ---- Local helpers (kept here so this file is fully standalone) ----
  TextStyle _rowLabelStyle(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final base = theme.textTheme.titleMedium ?? const TextStyle(fontSize: 16);
    return base.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700);
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.rowHighlight
        : Color.alphaBlend(cs.primary.withValues(alpha: 0.05), cs.surface);
    final hairline = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : cs.outline.withValues(alpha: 0.30);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hairline),
      ),
      child: child,
    );
  }

  Widget _secIcon(IconData icon) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: FaIcon(icon, size: 18),
  );

  Widget _secTitle(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Text(title,
        style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700));
  }

  Divider _hairline(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : cs.outline.withValues(alpha: 0.30),
      indent: 12,
      endIndent: 12,
    );
  }

  Widget _navRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      minLeadingWidth: 0,
      horizontalTitleGap: 12,
      dense: false,
      visualDensity: _kRowDensity,
      leading: FaIcon(icon, size: 18, color: cs.onSurface),
      title: Text(
        label,
        style: _rowLabelStyle(context),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, size: 14),
    );
  }

  /// Open a URL in an in‑app browser view (SFSafariViewController / Custom Tabs).
  Future<void> _openInAppBrowser(Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final supports = await supportsLaunchMode(LaunchMode.inAppBrowserView);
      final mode =
      supports ? LaunchMode.inAppBrowserView : LaunchMode.platformDefault;
      final ok = await launchUrl(uri, mode: mode);
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open ${uri.toString()}')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _card(
      context,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          visualDensity: _kTileDensity,
        ),
        child: ListTileTheme(
          dense: false,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.only(bottom: 6),
            initiallyExpanded: _expanded,
            onExpansionChanged: (v) {
              setState(() => _expanded = v);
              widget.onExpansionChanged?.call(v);
            },
            leading: _secIcon(FontAwesomeIcons.userPlus),
            title: _secTitle(context, l10n.dir_member_services),
            children: [
              _navRow(
                context: context,
                icon: FontAwesomeIcons.userPlus,
                label: l10n.dir_join_individual,
                onTap: () => _openInAppBrowser(widget.mIndiv),
              ),
              _hairline(context),
              _navRow(
                context: context,
                icon: FontAwesomeIcons.usersViewfinder,
                label: l10n.dir_join_family,
                onTap: () => _openInAppBrowser(widget.mFamily),
              ),
              _hairline(context),
              _navRow(
                context: context,
                icon: FontAwesomeIcons.rightToBracket,
                label: l10n.dir_renew_membership,
                onTap: () => _openInAppBrowser(widget.mRenew),
              ),
              // Disclaimer (only visible when expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.dir_membership_disclaimer,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}