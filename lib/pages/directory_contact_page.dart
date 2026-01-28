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
  static final Uri _telUri = Uri.parse('tel:+19723553937');
  static final Uri _webUri = Uri.parse('https://www.ialfm.org');
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
            FaIcon(FontAwesomeIcons.chevronRight, size: 14, color: textColor),
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
      color:
      isDark ? Colors.white.withOpacity(0.08) : cs.outline.withOpacity(0.30),
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
        if (!ok && c.mounted) {
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
          if (!ok && context.mounted) _toast(context, 'Could not open Maps');
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(aspectRatio: 16 / 9, child: image),
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
                          style:
                          const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFC7A447),
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
          icon:
          FaIcon(FontAwesomeIcons.copy, size: 16, color: cs.onSurface),
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

    final appBarBg = isLight ? Colors.white : AppColors.bgPrimary;
    final titleColor = isLight ? const Color(0xFF0F2432) : Colors.white;
    final iconsColor = titleColor;
    final overlay =
    isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

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
                    // --- CONTACT CARD ---
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

                    // --- MAP PREVIEW ---
                    _mapPreview(context),

                    const SizedBox(height: 32),

                    // --- FEEDBACK HEADER ---
                    Text(
                      "Feedback form for Masjid related issues,\nemail will be sent to IALFM Board of Directors.",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
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

  String _membershipStatusLine() {
    return isMember
        ? "Membership Status: IALFM Member"
        : "Membership Status: Not a Member";
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

    // Subject
    final String subject = Uri.encodeComponent(subjectCtrl.text.trim());

    // Body per your format
    final String bodyPlain = [
      "Feedback form submitted using IALFM Mobile App (${_platformString()})",
      "",
      _membershipStatusLine(),
      "",
      "--------------------",
      "Assalam Alaikum IALFM Board,",
      detailsCtrl.text.trim(),
    ].join("\n");

    final String body = Uri.encodeComponent(bodyPlain);

    // ---------- TESTING ----------
    final String to = "syed@ialfm.org";
    // ---------- PRODUCTION ----------
    // final String to = "bod@ialfm.org";

    final Uri uri = Uri.parse("mailto:$to?subject=$subject&body=$body");

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open email app")),
      );
      return;
    }

    if (!mounted) return;
    await _showSuccessDialog();

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

    final bool valid =
        subjectCtrl.text.trim().isNotEmpty && detailsCtrl.text.trim().isNotEmpty;

    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withOpacity(0.3)),
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
                  borderSide: BorderSide(color: onSurface.withOpacity(0.5)),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter a subject';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            // Membership toggle (SegmentedButton for zero ambiguity)
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
                  label: Text("IALFM Member"),
                  icon: Icon(Icons.verified_user_outlined),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text("Not a Member"),
                  icon: Icon(Icons.person_outline),
                ),
              ],
              selected: {isMember},
              onSelectionChanged: (s) => setState(() => isMember = s.first),
              style: ButtonStyle(
                visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
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
                  borderSide: BorderSide(color: onSurface.withOpacity(0.5)),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter details';
                }
                return null;
              },
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
                      : const Color(0xFFC7A447).withOpacity(0.45),
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

// -------- Animated success checkmark dialog (no extra packages) --------
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
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
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
                  color: Colors.black.withOpacity(0.1),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "You can send your feedback now.",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
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