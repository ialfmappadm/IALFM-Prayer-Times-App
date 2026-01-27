// lib/widgets/dst_pill_stealth.dart
import 'package:flutter/material.dart';

class DstPillStealth extends StatelessWidget {
  final bool isDst;
  final bool isLight;

  const DstPillStealth({
    super.key,
    required this.isDst,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    // Colors align to your app palette
    final Color fg = isDst
        ? const Color(0xFFC7A447)       // IALFM soft gold
        : (isLight ? Colors.black : Colors.white);

    final IconData icon = isDst
        ? Icons.access_time_filled        // visually distinct when ON
        : Icons.access_time;              // outline when OFF

    final String label = isDst ? 'DST' : 'STD';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: fg.withOpacity(0.10),      // soft tint, subtle
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}