
// lib/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color bgPrimary   = Color(0xFF0E1A2B); // deep navy
  static const Color bgSecondary = Color(0xFF14243A); // panels / rows
  static const Color rowHighlight= Color(0xFF1B2F4A); // subtle glow

  // Text
  static const Color textPrimary   = Color(0xFFFFFFFF); // titles, main numbers
  static const Color textSecondary = Color(0xFFC9D4E5); // labels like Salah, Adhan
  static const Color textMuted     = Color(0xFF9AA7BC); // less emphasis (Iqamah)
  static const Color countdownText = Color(0xFFF5E6A8); // special countdown numbers

  // Gold accents
  static const Color goldPrimary = Color(0xFFD4AF37); // current prayer, important icons
  static const Color goldSoft    = Color(0xFFE6C86E); // icons, moon, sunrise
  static const Color goldDivider = Color(0xFFB89B2E); // lines, underline

  // Icons & UI
  static const Color iconInactive = Color(0xFFA8B4C8);
  static const Color iconActive   = goldPrimary;
  static const Color outlineSubtle= Color(0xFF2A3F5F);

  // Special glyph colors
  static const Color moonStars = Color(0xFFF1D98A);
  static const Color sunrise   = Color(0xFFF2C94C);

  // Optional page background gradient
  static const Gradient pageGradient = LinearGradient(
    colors: [Color(0xFF0C1624), Color(0xFF162C46)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Header/info bar gradient (same as page or tweak if you like)
  static const Gradient headerGradient = pageGradient;
}
