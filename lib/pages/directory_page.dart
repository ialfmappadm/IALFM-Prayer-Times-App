
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../app_colors.dart';
import 'directory_contact_page.dart';
import 'directory_subpage.dart';

/// Simple model so the page is dynamic (add/remove rows, toggle chevron).
class _DirItem {
  final IconData icon;
  final String label;
  final void Function(BuildContext) onTap;
  final bool showChevron;
  const _DirItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showChevron = true,
  });
}

class DirectoryPage extends StatelessWidget {
  const DirectoryPage({super.key});

  // Labels
  static const String _tContact     = 'Contact Us';
  static const String _tImam        = 'Our Imam';
  static const String _tBoard       = 'Board of Directors';
  static const String _tSchool      = 'Sunday School';
  static const String _tNewsletter  = 'Newsletter';
  static const String _tPillars     = 'Pillars Academy';
  static const String _tQuranSchool = 'Quran School';
  static const String _tCalendar    = 'Annual Calendar';

  List<_DirItem> _items(BuildContext context) => <_DirItem>[
    _DirItem(
      icon: FontAwesomeIcons.phone,
      label: _tContact,
      onTap: (_) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DirectoryContactPage()),
      ),
    ),
    _DirItem(
      icon: FontAwesomeIcons.user,
      label: _tImam,
      onTap: (_) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DirectorySubPage(
            title: _tImam,
            body: _SectionPlaceholder(lines: ['Our Imam page content coming soon.']),
          ),
        ),
      ),
    ),
    _DirItem(
      icon: FontAwesomeIcons.users,
      label: _tBoard,
      onTap: (_) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DirectorySubPage(
            title: _tBoard,
            body: _SectionPlaceholder(lines: ['Board of Directors content coming soon.']),
          ),
        ),
      ),
    ),
    _DirItem(
      icon: FontAwesomeIcons.mosque,
      label: _tSchool,
      onTap: (_) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DirectorySubPage(
            title: _tSchool,
            body: _SectionPlaceholder(lines: ['Sunday School content coming soon.']),
          ),
        ),
      ),
    ),
    _DirItem(
      icon: FontAwesomeIcons.newspaper,
      label: _tNewsletter,
      onTap: (_) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DirectorySubPage(
            title: _tNewsletter,
            body: _SectionPlaceholder(lines: ['Newsletter sign‑up / archive coming soon.']),
          ),
        ),
      ),
    ),
    _DirItem(
      // ⬇️ Renamed icon
      icon: FontAwesomeIcons.bookQuran,
      label: _tPillars,
      onTap: (_) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DirectorySubPage(
            title: _tPillars,
            body: _SectionPlaceholder(lines: ['Pillars Academy information coming soon.']),
          ),
        ),
      ),
    ),
    _DirItem(
      icon: FontAwesomeIcons.bookOpen,
      label: _tQuranSchool,
      onTap: (_) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DirectorySubPage(
            title: _tQuranSchool,
            body: _SectionPlaceholder(lines: ['Quran School details coming soon.']),
          ),
        ),
      ),
    ),
    _DirItem(
      icon: FontAwesomeIcons.calendarCheck,
      label: _tCalendar,
      onTap: (_) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const DirectorySubPage(
            title: _tCalendar,
            body: _SectionPlaceholder(lines: ['Annual Calendar coming soon.']),
          ),
        ),
      ),
    ),
  ];

  // Reusable row UI (FA icon + label + optional chevron)
  Widget _row({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool showChevron, // ⬅️ now required (removes analyzer hint)
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
            if (showChevron)
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
    // ⬇️ withOpacity -> withValues(alpha: ...)
    color: Colors.white.withValues(alpha: 0.08),
    indent: 14,
    endIndent: 14,
  );

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final items = _items(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Directory',
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                // Grouped card with all rows
                Container(
                  decoration: BoxDecoration(
                    // ⬇️ withOpacity -> withValues(alpha: ...)
                    color: AppColors.bgPrimary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        _row(
                          icon: items[i].icon,
                          label: items[i].label,
                          onTap: () => items[i].onTap(context),
                          showChevron: items[i].showChevron, // ⬅️ always passed
                        ),
                        if (i < items.length - 1) _divider(),
                      ],
                    ],
                  ),
                ),
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