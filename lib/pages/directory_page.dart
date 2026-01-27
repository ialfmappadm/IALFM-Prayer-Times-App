
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../app_colors.dart';
import '../main.dart' show AppGradients;
import 'directory_contact_page.dart';

// NEW
import 'package:ialfm_prayer_times/l10n/generated/app_localizations.dart';

const String _latestNewsletterEndpoint = "https://latestnewsletter-kp6o4talda-uc.a.run.app";
final Uri _mailchimpArchiveUrl = Uri.parse(
  "https://us15.campaign-archive.com/home/?u=537cf06a4d5391e8cd0381f61&id=f9ee0724dc",
);

class DirectoryPage extends StatelessWidget {
  const DirectoryPage({super.key});

  static final Uri _imam        = Uri.parse('https://www.ialfm.org/our-imam/');
  static final Uri _board       = Uri.parse('https://www.ialfm.org/bod/');
  static final Uri _committees  = Uri.parse('https://www.ialfm.org/committees/');
  static final Uri _sundaySchool= Uri.parse('https://www.ialfm.org/ss-overview/');
  static final Uri _pillars     = Uri.parse('https://www.ialfm.org/pillars-academy/');
  static final Uri _quran       = Uri.parse('https://www.ialfm.org/quran-school/');
  static final Uri _mRenew      = Uri.parse('https://us.mohid.co/tx/dallas/ialfm/masjid/member/account/signin');
  static final Uri _mIndiv      = Uri.parse('https://us.mohid.co/tx/dallas/ialfm/masjid/online/membership/');
  static final Uri _mFamily     = Uri.parse('https://us.mohid.co/tx/dallas/ialfm/masjid/online/membership/L2VWRmVJcDFvUUJvUU4wdFU2TTlFdz09');
  static final Uri _calendar    = Uri.parse('https://www.ialfm.org/calendar/');
  static final Uri _erf         = Uri.parse('https://www.ialfm.org/erf/');
  static final Uri _docs        = Uri.parse('https://www.ialfm.org/ialfm-documents-forms/');
  static final Uri _volunteer   = Uri.parse('https://www.ialfm.org/volunteer/');
  static final Uri _linkTree    = Uri.parse('https://linktr.ee/ialfm');
  static final Uri _linkTreeYouth = Uri.parse('https://linktr.ee/ialfmyouth');

  Future<bool> _open(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${uri.toString()}')));
      }
      return ok;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
      return false;
    }
  }

  Future<void> _openLatestNewsletter(BuildContext context) async {
    try {
      final resp = await http.get(Uri.parse(_latestNewsletterEndpoint)).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final body = resp.body;
        final match = RegExp(r'"url"\s*:\s*"([^"]+)"').firstMatch(body);
        final url = match?.group(1);
        if (url != null) {
          final cleaned = url.replaceAll('&amp;', '&');
          await _open(context, Uri.parse(cleaned));
          return;
        }
      }
      await _open(context, _mailchimpArchiveUrl);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opened archive (latest link not available).')));
      }
    } catch (_) {
      await _open(context, _mailchimpArchiveUrl);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error — opened archive instead.')));
      }
    }
  }

  Widget _sectionHeader(BuildContext context, String title) {
    const gold = Color(0xFFC7A447);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Text(title, style: const TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark
        ? Color.alphaBlend(const Color(0xFF0A2C42).withValues(alpha: 0.25), Colors.black)
        : Color.alphaBlend(cs.primary.withValues(alpha: 0.05), cs.surface);
    final hairline = isDark ? Colors.white.withValues(alpha: 0.08) : cs.outline.withValues(alpha: 0.30);
    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: hairline)),
      child: child,
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
      leading: FaIcon(icon, size: 18, color: cs.onSurface),
      title: Text(label, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right, size: 14),
    );
  }

  Divider _hairline(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      color: isDark ? Colors.white.withValues(alpha: 0.08) : cs.outline.withValues(alpha: 0.30),
      indent: 12, endIndent: 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final gradients = Theme.of(context).extension<AppGradients>();
    final l10n = AppLocalizations.of(context)!;

    final appBarBg   = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? const Color(0xFF0F2432) : Colors.white;
    final overlay    = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text(l10n.tab_directory, style: TextStyle(color: titleColor, fontSize: 20, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: titleColor),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradients?.page),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              // CONTACT
              _sectionHeader(context, l10n.dir_section_contact),
              _card(
                context,
                child: _navRow(
                  context: context,
                  icon: FontAwesomeIcons.phone,
                  label: l10n.dir_contact_us,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DirectoryContactPage())),
                ),
              ),
              const SizedBox(height: 20),

              // MANAGEMENT
              _sectionHeader(context, l10n.dir_section_management),
              _card(
                context,
                child: Column(
                  children: [
                    _navRow(context: context, icon: FontAwesomeIcons.user,        label: l10n.dir_imam,       onTap: () => _open(context, _imam)),
                    _hairline(context),
                    _navRow(context: context, icon: FontAwesomeIcons.users,       label: l10n.dir_board,      onTap: () => _open(context, _board)),
                    _hairline(context),
                    _navRow(context: context, icon: FontAwesomeIcons.peopleGroup, label: l10n.dir_committees, onTap: () => _open(context, _committees)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // PROGRAMS
              _sectionHeader(context, l10n.dir_section_programs),
              _card(
                context,
                child: Column(
                  children: [
                    _navRow(context: context, icon: FontAwesomeIcons.school,    label: l10n.dir_sunday_school, onTap: () => _open(context, _sundaySchool)),
                    _hairline(context),
                    _navRow(context: context, icon: FontAwesomeIcons.bookQuran, label: l10n.dir_pillars,        onTap: () => _open(context, _pillars)),
                    _hairline(context),
                    _navRow(context: context, icon: FontAwesomeIcons.bookOpen,  label: l10n.dir_quran_school,   onTap: () => _open(context, _quran)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // MEMBERSHIP
              _sectionHeader(context, l10n.dir_membership),
              _card(
                context,
                child: Column(
                  children: [
                    _navRow(context: context, icon: FontAwesomeIcons.userPlus,        label: l10n.dir_signup_individual, onTap: () => _open(context, _mIndiv)),
                    _hairline(context),
                    _navRow(context: context, icon: FontAwesomeIcons.usersViewfinder, label: l10n.dir_signup_family,     onTap: () => _open(context, _mFamily)),
                    _hairline(context),
                    _navRow(context: context, icon: FontAwesomeIcons.rightToBracket,  label: l10n.dir_renew,             onTap: () => _open(context, _mRenew)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // RESOURCES
              _sectionHeader(context, l10n.dir_section_resources),
              _card(
                context,
                child: Column(
                  children: [
                    _navRow(
                      context: context,
                      icon: FontAwesomeIcons.newspaper,
                      label: l10n.dir_newsletter,
                      onTap: () async {
                        await showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          builder: (ctx) {
                            final cs = Theme.of(ctx).colorScheme;
                            return SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: FaIcon(FontAwesomeIcons.circlePlay, color: cs.onSurface, size: 18),
                                      title: Text(l10n.dir_open_latest_newsletter),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        await _openLatestNewsletter(context);
                                      },
                                    ),
                                    ListTile(
                                      leading: FaIcon(FontAwesomeIcons.list, color: cs.onSurface, size: 18),
                                      title: Text(l10n.dir_view_all_newsletters),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        await _open(context, _mailchimpArchiveUrl);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    _hairline(context),
                    _navRow(context: context, icon: FontAwesomeIcons.link,            label: l10n.dir_link_tree,      onTap: () => _open(context, _linkTree)),
                    _hairline(context),
                    _navRow(context: context, icon: FontAwesomeIcons.link,            label: l10n.dir_link_tree_youth,onTap: () => _open(context, _linkTreeYouth)),
                    _hairline(context),
                    _navRow(context: context, icon: FontAwesomeIcons.calendarCheck,   label: l10n.dir_calendar,       onTap: () => _open(context, _calendar)),
                    _hairline(context),
                    _navRow(context: context, icon: FontAwesomeIcons.lifeRing,        label: l10n.dir_erf,            onTap: () => _open(context, _erf)),
                    _hairline(context),
                    _navRow(context: context, icon: FontAwesomeIcons.fileLines,       label: l10n.dir_docs,           onTap: () => _open(context, _docs)),
                    _hairline(context),
                    _navRow(context: context, icon: FontAwesomeIcons.handsHelping,    label: l10n.dir_volunteer,      onTap: () => _open(context, _volunteer)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
