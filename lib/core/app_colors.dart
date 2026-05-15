// lib/core/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // ── Core Palette ────────────────────────────────────────────────────────
  static const Color bg           = Color(0xFF080C14);
   static const Color background = bg;
  static const Color bgSurface    = Color(0xFF0F1520);
  static const Color bgElevated   = Color(0xFF161E2E);
  static const Color bgHighlight  = Color(0xFF1A2436);
  static const Color bgModal      = Color(0xFF121B2A);   // modal / bottom sheet bg
  static const Color bgOverlay    = Color(0xFF1C2840);   // slightly lighter modal overlay

  // ── Brand Colors ────────────────────────────────────────────────────────
  static const Color brand        = Color(0xFF00D4FF);
  static const Color brandDark    = Color(0xFF0099BB);
  static const Color brandGlow    = Color(0x2200D4FF);
  static const Color brandSoft    = Color(0xFF0A2D3A);

  // ── Accent ──────────────────────────────────────────────────────────────
  static const Color accentGreen  = Color(0xFF00E5A0);
  static const Color accentOrange = Color(0xFFFF7B2C);
  static const Color accentRed    = Color(0xFFFF3D5A);
  static const Color accentYellow = Color(0xFFFFD166);
  static const Color accentPurple = Color(0xFFAB7EFF);   // system alerts, 4th accent

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFECF3FF);
  static const Color textSecondary = Color(0xFF8A9BB5);
  static const Color textMuted     = Color(0xFF3D4F68);
  static const Color textOnBrand   = Color(0xFF000D14);

  // ── Borders ─────────────────────────────────────────────────────────────
  static const Color border       = Color(0xFF1E2D42);
  static const Color borderBright = Color(0xFF253650);

  // ── Status ──────────────────────────────────────────────────────────────
  static const Color online   = Color(0xFF00E5A0);
  static const Color offline  = Color(0xFFFF3D5A);
  static const Color warning  = Color(0xFFFFD166);
  static const Color success  = Color(0xFF2ECC71);   // success (distinct from online)

  // ── Severity ─────────────────────────────────────────────────────────────
  static Color severityColor(String severity) {
    switch (severity) {
      case 'high':   return accentRed;
      case 'medium': return accentOrange;
      case 'low':    return accentYellow;
      default:       return accentOrange;
    }
  }

  // ── Alert type → consistent colour mapping ────────────────────────────────
  static Color alertTypeColor(String type) {
    switch (type) {
      case 'person':    return brand;
      case 'motion':    return accentOrange;   // fixed: was accentGreen in badge vs orange in screen
      case 'system':    return accentPurple;
      case 'recording': return textSecondary;
      default:          return brand;
    }
  }

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const Gradient brandGradient = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF0091FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Gradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF3D5A), Color(0xFFFF7B2C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Gradient cardGradient = LinearGradient(
    colors: [Color(0xFF0F1520), Color(0xFF0C1219)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Gradient bgGradient = LinearGradient(
    colors: [Color(0xFF080C14), Color(0xFF0C1520)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const Gradient purpleGradient = LinearGradient(
    colors: [Color(0xFFAB7EFF), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}