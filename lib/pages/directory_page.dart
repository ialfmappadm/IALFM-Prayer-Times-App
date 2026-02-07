// lib/pages/directory_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../app_colors.dart';
import '../main.dart' show AppGradients;
import 'directory_contact_page.dart';
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';

// Endpoints / Links
const String _latestNewsletterEndpoint =
    "https://latestnewsletter-kp6o4talda-uc.a.run.app";

final Uri _mailchimpArchiveUrl = Uri.parse(
  "https://us15.campaign-archive.com/home/?u=537cf06a4d5391e8cd0381f61&amp;id=f9ee0724dc",
);

class DirectoryPage extends StatefulWidget {
  const DirectoryPage({super.key});
  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  // ======= Comfortable layout tuning (adjust here if needed) =======
  static const double _kListPadV = 16;        // ListView vertical padding
  static const double _kSectionGap = 12;      // Gap between sections
  static const double _kHeaderVPad = 6;       // Section header top/bottom pad
  static const VisualDensity _kTileDensity =
  VisualDensity(horizontal: -1, vertical: -1.25); // ExpansionTile header density
  static const VisualDensity _kRowDensity =
  VisualDensity(horizontal: -1, vertical: -0.5);  // Rows inside tiles (mild)

  // Section links
  static final Uri _imam = Uri.parse('https://www.ialfm.org/our-imam/');
  static final Uri _board = Uri.parse('https://www.ialfm.org/bod/');
  static final Uri _committees =
  Uri.parse('https://www.ialfm.org/committees/');
  static final Uri _sundaySchool =
  Uri.parse('https://www.ialfm.org/ss-overview/');
  static final Uri _pillars = Uri.parse('https://www.ialfm.org/pillars-academy/');
  static final Uri _quran = Uri.parse('https://www.ialfm.org/quran-school/');

  static final Uri _mRenew = Uri.parse(
      'https://us.mohid.co/tx/dallas/ialfm/masjid/member/account/signin');
  static final Uri _mIndiv = Uri.parse(
      'https://us.mohid.co/tx/dallas/ialfm/masjid/online/membership/');
  static final Uri _mFamily = Uri.parse(
      'https://us.mohid.co/tx/dallas/ialfm/masjid/online/membership/L2VWRmVJcDFvUUJvUU4wdFU2TTlFdz09');

  static final Uri _calendar = Uri.parse('https://www.ialfm.org/calendar/');
  static final Uri _erf = Uri.parse('https://www.ialfm.org/erf/');
  static final Uri _docs =
  Uri.parse('https://www.ialfm.org/ialfm-documents-forms/');
  static final Uri _volunteer = Uri.parse('https://www.ialfm.org/volunteer/');
  static final Uri _linkTree = Uri.parse('https://linktr.ee/ialfm');
  static final Uri _linkTreeYouth = Uri.parse('https://linktr.ee/ialfmyouth');

  // Collapsed by default (match More page UX)
  bool _contactExpanded = false;
  bool _managementExpanded = false;
  bool _programsExpanded = false;
  bool _newsletterExpanded = false; // Newsletter section state
  bool _membershipExpanded = false;
  bool _resourcesExpanded = false;

  // List scroll control + anchor for Resources section
  final _listController = ScrollController();
  final _resourcesTileKey = GlobalKey();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Safe URL opener used in onTap (no prior await in same sync frame).
  // This method CAN use context because the call site doesn't have an async gap
  // before invoking it.
  Future<bool> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return false;
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open ${uri.toString()}')),
        );
      }
      return ok;
    } catch (_) {
      if (!mounted) return false;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
      return false;
    }
  }

  // Context-free opener for use AFTER awaits
  Future<bool> _openExternalWith({
    required Uri uri,
    required ScaffoldMessengerState messenger,
  }) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return false;
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open ${uri.toString()}')),
        );
      }
      return ok;
    } catch (_) {
      if (!mounted) return false;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
      return false;
    }
  }

  Future<void> _openLatestNewsletter(BuildContext context) async {
    // Resolve what we need BEFORE the awaits
    final messenger = ScaffoldMessenger.of(context);

    try {
      final resp = await http
          .get(Uri.parse(_latestNewsletterEndpoint))
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final body = resp.body;
        final match = RegExp(r'"url"\s*:\s*"([^"]+)"').firstMatch(body);
        final url = match?.group(1);
        if (url != null) {
          final cleaned = url.replaceAll('&amp;amp;', '&amp;');
          await _openExternalWith(uri: Uri.parse(cleaned), messenger: messenger);
          return;
        }
      }

      await _openExternalWith(uri: _mailchimpArchiveUrl, messenger: messenger);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Opened archive (latest link not available).')),
      );
    } catch (_) {
      await _openExternalWith(uri: _mailchimpArchiveUrl, messenger: messenger);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Network error — opened archive instead.')),
      );
    }
  }

  // Smoothly scroll Resources into view after it expands (lint‑clean, no async/await)
  void _scrollToResources() {
    void tryScroll({Duration duration = const Duration(milliseconds: 250)}) {
      // Always read a *fresh* context at the moment we scroll.
      final ctx = _resourcesTileKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: duration,
          curve: Curves.easeInOutCubic,
          alignment: 0.0, // place near the top; tweak to 0.02 if needed for app bar overlap
        );
      }
    }

    // 1) Right after the first re-layout (expansion has just begun).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tryScroll(duration: const Duration(milliseconds: 250));
    });

    // 2) A bit later, near the end of ExpansionTile's animation.
    Future.delayed(const Duration(milliseconds: 220), tryScroll);

    // 3) Optional final nudge for slower devices / longer animations.
    Future.delayed(const Duration(milliseconds: 400), tryScroll);
  }

  // ---------- Shared UI ----------

  /// Shared label style so sub-option rows match across pages.
  TextStyle _rowLabelStyle(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final base = theme.textTheme.titleMedium ?? const TextStyle(fontSize: 16);
    return base.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700);
  }

  Widget _sectionHeader(BuildContext context, String title) {
    const gold = Color(0xFFC7A447);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, _kHeaderVPad, 2, _kHeaderVPad),
      child: Text(
        title,
        style: const TextStyle(
          color: gold, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.rowHighlight
        : Color.alphaBlend(cs.primary.withValues(alpha: 0.05), cs.surface);
    final hairline =
    isDark ? Colors.white.withValues(alpha: 0.08) : cs.outline.withValues(alpha: 0.30);
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
    return Text(title, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700));
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
        style: _rowLabelStyle(context), // ← unified label style
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, size: 14),
    );
  }

  Divider _hairline(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      color: isDark ? Colors.white.withValues(alpha: 0.08) : cs.outline.withValues(alpha: 0.30),
      indent: 12,
      endIndent: 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final gradients = Theme.of(context).extension<AppGradients>();
    final l10n = AppLocalizations.of(context);
    final appBarBg = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? const Color(0xFF0F2432) : Colors.white;
    final overlay = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          l10n.tab_directory,
          style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: titleColor),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradients?.page),
        child: SafeArea(
          child: ListView(
            controller: _listController,
            padding: const EdgeInsets.fromLTRB(20, _kListPadV, 20, _kListPadV),
            children: [
              // CONTACT
              _sectionHeader(context, l10n.dir_section_contact),
              _card(
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
                      initiallyExpanded: _contactExpanded,
                      onExpansionChanged: (v) => setState(() => _contactExpanded = v),
                      leading: _secIcon(FontAwesomeIcons.phone),
                      title: _secTitle(context, l10n.dir_contact_us_feedback),
                      children: [
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.envelope,
                          label: l10n.dir_contact_us_feedback,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const DirectoryContactPage()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _kSectionGap),

              // MANAGEMENT
              _sectionHeader(context, l10n.dir_section_management),
              _card(
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
                      initiallyExpanded: _managementExpanded,
                      onExpansionChanged: (v) => setState(() => _managementExpanded = v),
                      leading: _secIcon(FontAwesomeIcons.users),
                      title: _secTitle(context, l10n.dir_section_management),
                      children: [
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.user,
                          label: l10n.dir_imam,
                          onTap: () => _open(context, _imam),
                        ),
                        _hairline(context),
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.users,
                          label: l10n.dir_board,
                          onTap: () => _open(context, _board),
                        ),
                        _hairline(context),
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.peopleGroup,
                          label: l10n.dir_committees,
                          onTap: () => _open(context, _committees),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _kSectionGap),

              // PROGRAMS
              _sectionHeader(context, l10n.dir_section_programs),
              _card(
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
                      initiallyExpanded: _programsExpanded,
                      onExpansionChanged: (v) => setState(() => _programsExpanded = v),
                      leading: _secIcon(FontAwesomeIcons.school),
                      title: _secTitle(context, l10n.dir_section_programs),
                      children: [
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.school,
                          label: l10n.dir_sunday_school,
                          onTap: () => _open(context, _sundaySchool),
                        ),
                        _hairline(context),
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.bookQuran,
                          label: l10n.dir_pillars,
                          onTap: () => _open(context, _pillars),
                        ),
                        _hairline(context),
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.bookOpen,
                          label: l10n.dir_quran_school,
                          onTap: () => _open(context, _quran),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _kSectionGap),

              // NEWSLETTER (moved out of Resources)
              _sectionHeader(context, l10n.dir_newsletter),
              _card(
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
                      initiallyExpanded: _newsletterExpanded,
                      onExpansionChanged: (v) => setState(() => _newsletterExpanded = v),
                      leading: _secIcon(FontAwesomeIcons.newspaper),
                      title: _secTitle(context, l10n.dir_newsletter),
                      children: [
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.circlePlay,
                          label: l10n.dir_open_latest_newsletter,
                          onTap: () async => _openLatestNewsletter(context),
                        ),
                        _hairline(context),
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.list,
                          label: l10n.dir_view_all_newsletters,
                          onTap: () async => _openExternalWith(
                            uri: _mailchimpArchiveUrl,
                            messenger: ScaffoldMessenger.of(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _kSectionGap),

              // MEMBERSHIP
              _sectionHeader(context, l10n.dir_membership),
              _card(
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
                      initiallyExpanded: _membershipExpanded,
                      onExpansionChanged: (v) => setState(() => _membershipExpanded = v),
                      leading: _secIcon(FontAwesomeIcons.userPlus),
                      title: _secTitle(context, l10n.dir_membership),
                      children: [
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.userPlus,
                          label: l10n.dir_signup_individual,
                          onTap: () => _open(context, _mIndiv),
                        ),
                        _hairline(context),
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.usersViewfinder,
                          label: l10n.dir_signup_family,
                          onTap: () => _open(context, _mFamily),
                        ),
                        _hairline(context),
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.rightToBracket,
                          label: l10n.dir_renew,
                          onTap: () => _open(context, _mRenew),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _kSectionGap),

              // RESOURCES
              _sectionHeader(context, l10n.dir_section_resources),
              _card(
                context,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    visualDensity: _kTileDensity,
                  ),
                  child: ListTileTheme(
                    dense: false,
                    child: ExpansionTile(
                      key: _resourcesTileKey,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.only(bottom: 6),
                      initiallyExpanded: _resourcesExpanded,
                      onExpansionChanged: (v) {
                        setState(() => _resourcesExpanded = v);
                        if (v) {
                          _scrollToResources();
                        }
                      },
                      leading: _secIcon(FontAwesomeIcons.folderOpen),
                      title: _secTitle(context, l10n.dir_section_resources),
                      children: [
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.link,
                          label: l10n.dir_link_tree,
                          onTap: () => _open(context, _linkTree),
                        ),
                        _hairline(context),
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.link,
                          label: l10n.dir_link_tree_youth,
                          onTap: () => _open(context, _linkTreeYouth),
                        ),
                        _hairline(context),
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.calendarCheck,
                          label: l10n.dir_calendar,
                          onTap: () => _open(context, _calendar),
                        ),
                        _hairline(context),
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.lifeRing,
                          label: l10n.dir_erf,
                          onTap: () => _open(context, _erf),
                        ),
                        _hairline(context),
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.fileLines,
                          label: l10n.dir_docs,
                          onTap: () => _open(context, _docs),
                        ),
                        _hairline(context),
                        _navRow(
                          context: context,
                          icon: FontAwesomeIcons.handshakeAngle,
                          label: l10n.dir_volunteer,
                          onTap: () => _open(context, _volunteer),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: _kSectionGap),
            ],
          ),
        ),
      ),
    );
  }
}