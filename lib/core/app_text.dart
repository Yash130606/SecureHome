// lib/core/app_text.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppText {
  // ── Display ──────────────────────────────────────────────────────────────
  static TextStyle hero({Color color = AppColors.textPrimary}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 42, fontWeight: FontWeight.w800,
        color: color, letterSpacing: -1.5, height: 1.05,
      );

  static TextStyle h1({Color color = AppColors.textPrimary}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 28, fontWeight: FontWeight.w700,
        color: color, letterSpacing: -0.8,
      );

  static TextStyle h2({Color color = AppColors.textPrimary}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 22, fontWeight: FontWeight.w600,
        color: color, letterSpacing: -0.4,
      );

  static TextStyle h3({Color color = AppColors.textPrimary}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: color, letterSpacing: -0.2,
      );

  // ── Body ─────────────────────────────────────────────────────────────────
  static TextStyle bodyL({Color color = AppColors.textSecondary}) =>
      GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w400, color: color, height: 1.6);

  static TextStyle bodyM({Color color = AppColors.textSecondary}) =>
      GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w400, color: color, height: 1.5);

  static TextStyle bodyMBold({Color color = AppColors.textPrimary}) =>
      GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: color, height: 1.5);

  static TextStyle bodyS({Color color = AppColors.textMuted}) =>
      GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w400, color: color);

  // ── Label / UI ───────────────────────────────────────────────────────────
  static TextStyle label({Color color = AppColors.textSecondary, double size = 11}) =>
      GoogleFonts.dmSans(
        fontSize: size, fontWeight: FontWeight.w600,
        color: color, letterSpacing: 0.9,
      );

  /// Caption — 10pt for timestamps, helper text
  static TextStyle caption({Color color = AppColors.textMuted}) =>
      GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w400, color: color);

  /// Overline — 10pt uppercase with wide spacing (section headers, tags)
  static TextStyle overline({Color color = AppColors.textMuted}) =>
      GoogleFonts.dmSans(
        fontSize: 10, fontWeight: FontWeight.w600,
        color: color, letterSpacing: 1.5,
      ).copyWith(decoration: TextDecoration.none);

  // ── Button — fixed: default color is brand (was textOnBrand which is dark) ──
  static TextStyle btn({Color color = AppColors.textOnBrand}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: 15, fontWeight: FontWeight.w700,
        color: color, letterSpacing: 0.2,
      );

  // ── Mono ─────────────────────────────────────────────────────────────────
  static TextStyle mono({Color color = AppColors.textSecondary, double size = 12}) =>
      GoogleFonts.sourceCodePro(
        fontSize: size, fontWeight: FontWeight.w500,
        color: color, letterSpacing: 0.5,
      );
}