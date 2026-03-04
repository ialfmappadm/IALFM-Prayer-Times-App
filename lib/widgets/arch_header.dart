import 'package:flutter/material.dart';
import '../app_colors.dart';

/// Gold arch painter — drawn INSIDE the header background so it matches light/dark themes.
class _ArchPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  _ArchPainter({required this.color, this.strokeWidth = 6.0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(w * 0.02, h * 0.70)
      ..cubicTo(w * 0.12, h * 0.55, w * 0.22, h * 0.35, w * 0.33, h * 0.22)
      ..cubicTo(w * 0.41, h * 0.14, w * 0.46, h * 0.08, w * 0.50, h * 0.05)
      ..cubicTo(w * 0.54, h * 0.08, w * 0.59, h * 0.14, w * 0.67, h * 0.22)
      ..cubicTo(w * 0.78, h * 0.35, w * 0.88, h * 0.55, w * 0.98, h * 0.70);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArchPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

/// Header with matching background + an arch painted behind content.
/// The arch is positioned with a Stack so it **does not** consume layout height.
class ArchHeader extends StatelessWidget {
  const ArchHeader({
    super.key,
    required this.isLight,
    required this.logo,
    required this.title,
    required this.dateRow,
    required this.toolsRow,
    this.archHeight = 100,
  });

  final bool isLight;
  final Widget logo;
  final Widget title;
  final Widget dateRow;  // the big (Gregorian • Hijri) line
  final Widget toolsRow; // calendar / poster toggle row
  final double archHeight;

  @override
  Widget build(BuildContext context) {
    final headerDecoration = isLight
        ? const BoxDecoration(color: Colors.white)
        : const BoxDecoration(gradient: AppColors.headerGradient);

    return Stack(
      children: [
        // Background (light solid or dark gradient)
        Container(decoration: headerDecoration),

        // Arch painted **inside** header, so colors match; doesn’t take layout height
        Positioned(
          top: 0, left: 0, right: 0,
          height: archHeight,
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ArchPainter(color: const Color(0xFFC7A447), strokeWidth: 6),
            ),
          ),
        ),

        // Content column
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              logo,
              const SizedBox(height: 12),
              title,
              const SizedBox(height: 12),
              toolsRow,
              const SizedBox(height: 4),
              dateRow,
              const SizedBox(height: 8),
              Container(height: 1, color: AppColors.goldDivider),
            ],
          ),
        ),
      ],
    );
  }
}