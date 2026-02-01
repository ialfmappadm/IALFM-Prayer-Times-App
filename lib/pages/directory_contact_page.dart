// lib/pages/directory_contact_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // defaultTargetPlatform
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_colors.dart';
import '../main.dart' show AppGradients;

class DirectoryContactPage extends StatelessWidget {
  const DirectoryContactPage({super.key});

  // === CONTACT INFO ===
  static const String _displayPhone = '972-355-3937';
  static final Uri _telUri  = Uri.parse('tel:+19723553937');
  static final Uri _webUri  = Uri.parse('https://www.ialfm.org');
  static final Uri _mailUri = Uri.parse('mailto:info@ialfm.org');

  // === LOCATION ===
  static const String _address =
      '3430 Peters Colony Rd., Flower Mound, TX 75022';
  static final Uri _mapsUri = Uri.parse(
      'https://maps.google.com/?q=3430+Peters+Colony+Rd.,+Flower+Mound,+TX+75022');

  // === LOCAL MAP IMAGE ===
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

  // ---------- Private helpers (methods of this widget) ----------
  Widget _row({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
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
            const FaIcon(FontAwesomeIcons.chevronRight, size: 14),
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
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : cs.outline.withValues(alpha: 0.30),
      indent: 14,
      endIndent: 14,
    );
  }

  Widget _mapPreview(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final image = Image.asset(
      _mapAsset,
      fit: BoxFit.cover,
      errorBuilder: (c, _, __) => _MapPlaceholder(onTap: () async {
        final ok = await _open(_mapsUri);
        if (c.mounted && !ok) {
          ScaffoldMessenger.of(c)
              .showSnackBar(const SnackBar(content: Text('Could not open Maps')));
        }
      }),
    );

    final mapCard = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final ok = await _open(_mapsUri);
          if (!context.mounted) return;
          if (!ok) _toast(context, 'Could not open Maps');
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          color: const Color(0xFFC7A447), // gold CTA
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

    // Address line + copy affordance
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
            if (!context.mounted) return;
            _toast(context, 'Address copied');
          },
          icon: FaIcon(FontAwesomeIcons.copy, size: 16, color: cs.onSurface),
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
    final theme     = Theme.of(context);
    final isLight   = theme.brightness == Brightness.light;
    final cs        = theme.colorScheme;
    final gradients = theme.extension<AppGradients>();
    final appBarBg  = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? const Color(0xFF0F2432) : Colors.white;
    final iconsColor = titleColor;
    final overlay    = isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

    // 🔹 CHANGE: align contact card with Salah table highlight in dark mode.
    final Color cardFill = isLight
        ? Color.alphaBlend(cs.primary.withValues(alpha: 0.05), cs.surface)
        : AppColors.rowHighlight; // same “light navy-ish” as table highlight

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Contact Us & Feedback',
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
                    // --- CONTACT CARD ---
                    Container(
                      decoration: BoxDecoration(
                        color: cardFill, // ✅ uses AppColors.rowHighlight in DARK
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
                              if (!context.mounted) return;
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
                              if (!context.mounted) return;
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
                              if (!context.mounted) return;
                              if (!ok) _toast(context, 'Could not open email');
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- MAP PREVIEW ---
                    _mapPreview(context),

                    const SizedBox(height: 32),

                    // --- FEEDBACK HEADER ---
                    Text(
                      "Contact Us & Feedback",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Email will be sent to the IALFM Board of Directors.",
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- FEEDBACK FORM ---
                    const FeedbackForm(),
                    const SizedBox(height: 48),
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

// ====================== FEEDBACK FORM =========================
class FeedbackForm extends StatefulWidget {
  const FeedbackForm({super.key});
  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController subjectCtrl = TextEditingController();
  final TextEditingController detailsCtrl = TextEditingController();

  /// toggle: true => member, false => not member
  bool isMember = true;

  @override
  void dispose() {
    subjectCtrl.dispose();
    detailsCtrl.dispose();
    super.dispose();
  }

  String _platformString() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return "iOS";
      case TargetPlatform.android:
        return "Android";
      default:
        return "Unknown Platform";
    }
  }

  Future<void> _showSuccessDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _SuccessCheckDialog(),
    );
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final subject = Uri.encodeComponent(subjectCtrl.text.trim());
    final bodyPlain = [
      "Feedback form submitted using IALFM Mobile App (${_platformString()})",
      "",
      isMember
          ? "Membership Status: I'm a member"
          : "Membership Status: I'm currently not a member",
      "",
      "--------------------",
      "Assalam Alaikum IALFM Board,",
      detailsCtrl.text.trim(),
    ].join("\n");
    final body = Uri.encodeComponent(bodyPlain);

    // TEST
    final to = "syed@ialfm.org";
    // PROD: final to = "bod@ialfm.org";
    final uri = Uri.parse("mailto:$to?subject=$subject&body=$body");

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open email app")),
      );
      return;
    }
    await _showSuccessDialog();
    if (!mounted) return;
    setState(() {
      subjectCtrl.clear();
      detailsCtrl.clear();
      isMember = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
    );
    final valid =
        subjectCtrl.text.trim().isNotEmpty && detailsCtrl.text.trim().isNotEmpty;

    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject (required)
            Text(
              "Subject",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: subjectCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: "Enter a brief subject line",
                border: fieldBorder,
                enabledBorder: fieldBorder,
                focusedBorder: fieldBorder.copyWith(
                  borderSide: BorderSide(color: onSurface.withValues(alpha: 0.5)),
                ),
              ),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter a subject' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Membership toggle (SegmentedButton)
            Text(
              "Membership Status",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text("I'm a member"),
                  icon: Icon(Icons.verified_user_outlined),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text("I'm not a member"),
                  icon: Icon(Icons.person_outline),
                ),
              ],
              selected: {isMember},
              onSelectionChanged: (s) => setState(() => isMember = s.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity(horizontal: -1, vertical: -2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(height: 16),

            // Details (required)
            Text(
              "Details",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: detailsCtrl,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: "Describe the issue or suggestion…",
                border: fieldBorder,
                enabledBorder: fieldBorder,
                focusedBorder: fieldBorder.copyWith(
                  borderSide: BorderSide(color: onSurface.withValues(alpha: 0.5)),
                ),
              ),
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter details' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // Send
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: valid
                      ? const Color(0xFFC7A447)
                      : const Color(0xFFC7A447).withValues(alpha: 0.45),
                  foregroundColor: Colors.black,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                onPressed: valid ? _sendEmail : null,
                child: const Text(
                  "Send Feedback",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Animated success checkmark dialog ----------
class _SuccessCheckDialog extends StatefulWidget {
  const _SuccessCheckDialog();
  @override
  State<_SuccessCheckDialog> createState() => _SuccessCheckDialogState();
}

class _SuccessCheckDialogState extends State<_SuccessCheckDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _scale = CurvedAnimation(parent: _ac, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 56),
                SizedBox(height: 12),
                Text(
                  'Email app opened',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  "You can send your feedback now.",
                  style: TextStyle(fontSize: 13),
                ),
              ],
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
          color: Colors.white.withValues(alpha: 0.06),
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