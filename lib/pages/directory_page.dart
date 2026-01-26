
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

// NEW: match navy background like Announcement/Contact
import '../app_colors.dart';
import '../main.dart' show AppGradients;
import 'directory_contact_page.dart';

// ====== 🔧 CONFIGURE THESE TWO ======
const String _latestNewsletterEndpoint =
    "https://latestnewsletter-kp6o4talda-uc.a.run.app"; // Cloud Run URL (v2)

final Uri _mailchimpArchiveUrl = Uri.parse(
  // TIP: paste your Mailchimp archive page URL here
  "https://us15.campaign-archive.com/home/?u=537cf06a4d5391e8cd0381f61&id=f9ee0724dc",
);

// ====== PAGE WIDGET ======
class DirectoryPage extends StatelessWidget {
  const DirectoryPage({super.key});

  // ---- Page title
  static const String _tDirectory = 'Directory';

  // ---- Section headers
  static const String _sContact = 'Contact';
  static const String _sManagement = 'Management';
  static const String _sPrograms = 'Programs';
  static const String _sResources = 'Resources';

  // ---- Labels
  static const String _tContact = 'Contact Us';
  static const String _tImam = 'Our Imam';
  static const String _tBoard = 'Board of Directors';
  static const String _tCommittees = 'Committees';

  static const String _tSundaySchool = 'Sunday School';
  static const String _tPillars = 'Pillars Academy';
  static const String _tQuranSchool = 'Quran School';

  static const String _tMembership = 'Membership';
  static const String _tSignupInd = 'Signup – Individual';
  static const String _tSignupFam = 'Signup – Family';
  static const String _tRenew = 'Renew (Member Login)';

  static const String _tNewsletter = 'Newsletter';
  static const String _tLinkTree = 'Link Tree - IALFM';
  static const String _tLinkTreeYouth = 'Link Tree - IALFM Youth';
  static const String _tCalendar = 'Annual Calendar';
  static const String _tERF = 'Emergency Relief Fund';
  static const String _tDocs = 'IALFM Documents';
  static const String _tVolunteer = 'Become a Volunteer';

  // ---- External links
  static final Uri _imam = Uri.parse('https://www.ialfm.org/our-imam/');
  static final Uri _board = Uri.parse('https://www.ialfm.org/bod/');
  static final Uri _committees = Uri.parse('https://www.ialfm.org/committees/');

  static final Uri _sundaySchool = Uri.parse('https://www.ialfm.org/ss-overview/');
  static final Uri _pillars = Uri.parse('https://www.ialfm.org/pillars-academy/');
  static final Uri _quran = Uri.parse('https://www.ialfm.org/quran-school/');

  static final Uri _mRenew = Uri.parse('https://us.mohid.co/tx/dallas/ialfm/masjid/member/account/signin');
  static final Uri _mIndiv = Uri.parse('https://us.mohid.co/tx/dallas/ialfm/masjid/online/membership/');
  static final Uri _mFamily = Uri.parse('https://us.mohid.co/tx/dallas/ialfm/masjid/online/membership/L2VWRmVJcDFvUUJvUU4wdFU2TTlFdz09');

  static final Uri _calendar = Uri.parse('https://www.ialfm.org/calendar/');
  static final Uri _erf = Uri.parse('https://www.ialfm.org/erf/');
  static final Uri _docs = Uri.parse('https://www.ialfm.org/ialfm-documents-forms/');
  static final Uri _volunteer = Uri.parse('https://www.ialfm.org/volunteer/');
  static final Uri _linkTree = Uri.parse('https://linktr.ee/ialfm');
  static final Uri _linkTreeYouth = Uri.parse('https://linktr.ee/ialfmyouth');

  // ---- Helpers
  Future<bool> _open(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open ${uri.toString()}')),
        );
      }
      return ok;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
      return false;
    }
  }

  Future<void> _openLatestNewsletter(BuildContext context) async {
    try {
      final resp = await http
          .get(Uri.parse(_latestNewsletterEndpoint))
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final body = resp.body;
        final match = RegExp(r'"url"\s*:\s*"([^"]+)"').firstMatch(body);
        final url = match?.group(1);
        if (url != null) {
          // Normalize any &amp; that may slip through
          final cleaned = url.replaceAll('&amp;', '&');
          await _open(context, Uri.parse(cleaned));
          return;
        }
      }
      // Fallback
      await _open(context, _mailchimpArchiveUrl);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opened archive (latest link not available).')),
        );
      }
    } catch (_) {
      await _open(context, _mailchimpArchiveUrl);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error — opened archive instead.')),
        );
      }
    }
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Text(
        title,
        style: TextStyle(
          color: cs.secondary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.28)),
      ),
      child: child,
    );
  }

  Widget _row({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            FaIcon(icon, size: 18, color: cs.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FaIcon(FontAwesomeIcons.chevronRight, size: 14, color: cs.onSurface),
          ],
        ),
      ),
    );
  }

  Widget _divider(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(height: 1, color: cs.outline.withOpacity(0.28), indent: 12, endIndent: 12);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Use the same navy treatment as other pages (Announcement/Contact/Social)
    final gradients = theme.extension<AppGradients>();
    final appBarBg = isLight ? Colors.white : AppColors.bgPrimary;
    final overlay = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    return Scaffold(
      // Let the gradient paint the page; Scaffold remains transparent
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          _tDirectory,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        systemOverlayStyle: overlay,
      ),
      body: Container(
        // Match navy background across pages
        decoration: BoxDecoration(gradient: gradients?.page),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              // ===== CONTACT =====
              _sectionHeader(context, _sContact),
              _card(
                context,
                child: _row(
                  context: context,
                  icon: FontAwesomeIcons.phone,
                  label: _tContact,
                  onTap: () {
                    // 👉 Wire Contact Us → DirectoryContactPage
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DirectoryContactPage()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // ===== MANAGEMENT =====
              _sectionHeader(context, _sManagement),
              _card(
                context,
                child: Column(
                  children: [
                    _row(context: context, icon: FontAwesomeIcons.user,        label: _tImam,        onTap: () => _open(context, _imam)),
                    _divider(context),
                    _row(context: context, icon: FontAwesomeIcons.users,       label: _tBoard,       onTap: () => _open(context, _board)),
                    _divider(context),
                    _row(context: context, icon: FontAwesomeIcons.peopleGroup, label: _tCommittees,  onTap: () => _open(context, _committees)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ===== PROGRAMS =====
              _sectionHeader(context, _sPrograms),
              _card(
                context,
                child: Column(
                  children: [
                    _row(context: context, icon: FontAwesomeIcons.school,    label: _tSundaySchool, onTap: () => _open(context, _sundaySchool)),
                    _divider(context),
                    _row(context: context, icon: FontAwesomeIcons.bookQuran, label: _tPillars,      onTap: () => _open(context, _pillars)),
                    _divider(context),
                    _row(context: context, icon: FontAwesomeIcons.bookOpen,  label: _tQuranSchool,  onTap: () => _open(context, _quran)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ===== MEMBERSHIP =====
              _sectionHeader(context, _tMembership),
              _card(
                context,
                child: Column(
                  children: [
                    _row(context: context, icon: FontAwesomeIcons.userPlus,        label: _tSignupInd, onTap: () => _open(context, _mIndiv)),
                    _divider(context),
                    _row(context: context, icon: FontAwesomeIcons.usersViewfinder, label: _tSignupFam, onTap: () => _open(context, _mFamily)),
                    _divider(context),
                    _row(context: context, icon: FontAwesomeIcons.rightToBracket,  label: _tRenew,     onTap: () => _open(context, _mRenew)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ===== RESOURCES =====
              _sectionHeader(context, _sResources),
              _card(
                context,
                child: Column(
                  children: [
                    // Newsletter → sheet with Latest vs All Past
                    _row(
                      context: context,
                      icon: FontAwesomeIcons.newspaper,
                      label: _tNewsletter,
                      onTap: () async {
                        await showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
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
                                      title: const Text('Open Latest Newsletter'),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        await _openLatestNewsletter(context);
                                      },
                                    ),
                                    ListTile(
                                      leading: FaIcon(FontAwesomeIcons.list, color: cs.onSurface, size: 18),
                                      title: const Text('View All Past Newsletters'),
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
                    _divider(context),

                    _row(context: context, icon: FontAwesomeIcons.link, label: _tLinkTree,       onTap: () => _open(context, _linkTree)),
                    _divider(context),
                    _row(context: context, icon: FontAwesomeIcons.link, label: _tLinkTreeYouth,  onTap: () => _open(context, _linkTreeYouth)),
                    _divider(context),

                    _row(context: context, icon: FontAwesomeIcons.calendarCheck, label: _tCalendar,  onTap: () => _open(context, _calendar)),
                    _divider(context),
                    _row(context: context, icon: FontAwesomeIcons.lifeRing,      label: _tERF,       onTap: () => _open(context, _erf)),
                    _divider(context),
                    _row(context: context, icon: FontAwesomeIcons.fileLines,     label: _tDocs,      onTap: () => _open(context, _docs)),
                    _divider(context),
                    _row(context: context, icon: FontAwesomeIcons.handsHelping,  label: _tVolunteer, onTap: () => _open(context, _volunteer)),
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