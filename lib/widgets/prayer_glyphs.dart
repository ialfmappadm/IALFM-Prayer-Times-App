
// lib/widgets/prayer_glyphs.dart
import 'package:flutter/material.dart';

Widget prayerGlyph(
    String label, {
      Color? color,
      double size = 20,
    }) {
  final lower = label.trim().toLowerCase();

  if (lower == 'sunrise') {
    return _SunWithArrow(color: color ?? Colors.amber, size: size, up: true);
  } else if (lower == 'maghrib') {
    return _SunWithArrow(color: color ?? Colors.amber, size: size, up: false);
  } else if (lower == 'isha') {
    return Icon(Icons.nightlight_round, color: color ?? Colors.amber, size: size);
  }
  return const SizedBox.shrink();
}

class _SunWithArrow extends StatelessWidget {
  final Color color;
  final double size;
  final bool up;

  const _SunWithArrow({
    super.key,
    required this.color,
    required this.size,
    required this.up,
  });

  @override
  Widget build(BuildContext context) {
    final IconData arrowIcon = up ? Icons.north : Icons.south;
    final double arrowSize = size * 0.8;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.wb_sunny, color: color, size: size),
        const SizedBox(width: 2),
        Icon(arrowIcon, color: color, size: arrowSize),
      ],
    );
  }
}
