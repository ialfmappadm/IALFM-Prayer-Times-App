
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_colors.dart';
import 'directory_contact_page.dart';
import 'directory_subpage.dart';

class DirectoryPage extends StatelessWidget {
  const DirectoryPage({super.key});

  // ---- Labels
  static const String _tDirectory = 'Directory';
  static const String _tContact = 'Contact Us';
  static const String _tImam = 'Our Imam';
  static const String _tBoard = 'Board of Directors';

  static const String _tSundaySchool = 'Sunday School';
  static const String _tPillars = 'Pillars Academy';
  static const String _tQuranSchool = 'Quran School';

  static const String _tNewsletter = 'Newsletter';
  static const String _tLinkTree = 'Link Tree';
  static const String _tCalendar = 'Annual Calendar';

  // ---- Sections
  static const String _sManagement = 'Management';
  static const String _sPrograms = 'Programs';
  static const String _sResources = 'Resources';

  // TODO: put your real Link Tree / hub URL here
  static const String _linkTreeUrl = 'https://linktr.ee/ialfm';

  // ---- Helpers
  Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Widget _sectionHeader(String title) {
    const gold = Color(0xFFC9A23F);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: gold,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Material(
        color: AppColors.bgPrimary.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            // ~48dp+ tap target
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Row(
              children: [
                FaIcon(icon, color: AppColors.textPrimary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    // Increased to 18 for readability
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
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
        ),
      ),
    );
  }

  // Small gap between rows
  Widget get _rowGap => const SizedBox(height: 8);

  // Large gap between sections
  Widget get _sectionGap => const SizedBox(height: 24);

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          _tDirectory,
          style: TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          // Full-screen gradient background
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.pageGradient)),
          ),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                // Title spacing from top
                SliverToBoxAdapter(child: SizedBox(height: 12)),
                // Page horizontal padding
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.list(children: [
                    // ========== MANAGEMENT ==========
                    _sectionHeader(_sManagement),
                    _card(
                      icon: FontAwesomeIcons.phone,
                      label: _tContact,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DirectoryContactPage()),
                        );
                      },
                    ),
                    _rowGap,
                    _card(
                      icon: FontAwesomeIcons.user,
                      label: _tImam,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DirectorySubPage(
                              title: _tImam,
                              body: _SectionPlaceholder(lines: ['Our Imam page content coming soon.']),
                            ),
                          ),
                        );
                      },
                    ),
                    _rowGap,
                    _card(
                      icon: FontAwesomeIcons.users,
                      label: _tBoard,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DirectorySubPage(
                              title: _tBoard,
                              body: _SectionPlaceholder(lines: ['Board of Directors content coming soon.']),
                            ),
                          ),
                        );
                      },
                    ),

                    _sectionGap,

                    // ========== PROGRAMS ==========
                    _sectionHeader(_sPrograms),
                    _card(
                      icon: FontAwesomeIcons.school, // or FontAwesomeIcons.mosque
                      label: _tSundaySchool,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DirectorySubPage(
                              title: _tSundaySchool,
                              body: _SectionPlaceholder(lines: ['Sunday School content coming soon.']),
                            ),
                          ),
                        );
                      },
                    ),
                    _rowGap,
                    _card(
                      icon: FontAwesomeIcons.bookQuran,
                      label: _tPillars,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DirectorySubPage(
                              title: _tPillars,
                              body: _SectionPlaceholder(lines: ['Pillars Academy information coming soon.']),
                            ),
                          ),
                        );
                      },
                    ),
                    _rowGap,
                    _card(
                      icon: FontAwesomeIcons.bookOpen,
                      label: _tQuranSchool,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DirectorySubPage(
                              title: _tQuranSchool,
                              body: _SectionPlaceholder(lines: ['Quran School details coming soon.']),
                            ),
                          ),
                        );
                      },
                    ),

                    _sectionGap,

                    // ========== RESOURCES ==========
                    _sectionHeader(_sResources),
                    _card(
                      icon: FontAwesomeIcons.newspaper,
                      label: _tNewsletter,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DirectorySubPage(
                              title: _tNewsletter,
                              body: _SectionPlaceholder(lines: ['Newsletter sign‑up / archive coming soon.']),
                            ),
                          ),
                        );
                      },
                    ),
                    _rowGap,
                    _card(
                      icon: FontAwesomeIcons.link,
                      label: _tLinkTree,
                      onTap: () async {
                        final ok = await _open(Uri.parse(_linkTreeUrl));
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Could not open Link Tree')));
                        }
                      },
                    ),
                    _rowGap,
                    _card(
                      icon: FontAwesomeIcons.calendarCheck,
                      label: _tCalendar,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DirectorySubPage(
                              title: _tCalendar,
                              body: _SectionPlaceholder(lines: ['Annual Calendar coming soon.']),
                            ),
                          ),
                        );
                      },
                    ),

                    // Bottom padding
                    const SizedBox(height: 24),
                  ]),
                ),

                // Fill the rest so content reaches bottom on tall screens
                SliverFillRemaining(hasScrollBody: false, child: const SizedBox(height: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  final List<String> lines;
  const _SectionPlaceholder({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final l in lines) ...[
          Text(
            l,
            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}