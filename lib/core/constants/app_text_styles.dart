import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Gaya teks = token `fontSize` di tailwind.config desain.
/// - letter-spacing di CSS memakai satuan em, di sini dikonversi ke px.
/// - `leadingDistribution: even` meniru cara CSS membagi line-height
///   (setengah di atas, setengah di bawah) supaya posisi teks sama persis.
class AppTextStyles {
  AppTextStyles._();

  // ---- helper dasar ------------------------------------------------------
  static TextStyle outfit({
    required double size,
    required double lineHeight,
    double tracking = 0, // em
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.outfit(
        fontSize: size,
        height: lineHeight / size,
        letterSpacing: tracking * size,
        fontWeight: weight,
        color: color,
      ).copyWith(leadingDistribution: TextLeadingDistribution.even);

  static TextStyle jakarta({
    required double size,
    required double lineHeight,
    double tracking = 0, // em
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        height: lineHeight / size,
        letterSpacing: tracking * size,
        fontWeight: weight,
        color: color,
      ).copyWith(leadingDistribution: TextLeadingDistribution.even);

  // ---- Headline (Outfit) -------------------------------------------------
  static TextStyle headlineXl({Color? color}) => outfit(
      size: 36, lineHeight: 44, tracking: -0.025, weight: FontWeight.w700, color: color);
  static TextStyle headlineLg({Color? color}) => outfit(
      size: 28, lineHeight: 36, tracking: -0.02, weight: FontWeight.w600, color: color);
  static TextStyle headlineMd({Color? color}) => outfit(
      size: 22, lineHeight: 28, tracking: -0.015, weight: FontWeight.w600, color: color);
  static TextStyle headlineSm({Color? color}) => outfit(
      size: 18, lineHeight: 24, tracking: -0.01, weight: FontWeight.w600, color: color);

  // ---- Body (Plus Jakarta Sans) -----------------------------------------
  static TextStyle bodyLg({FontWeight weight = FontWeight.w400, Color? color}) =>
      jakarta(size: 16, lineHeight: 24, weight: weight, color: color);
  static TextStyle bodyMd({FontWeight weight = FontWeight.w400, Color? color}) =>
      jakarta(size: 14, lineHeight: 22, weight: weight, color: color);
  static TextStyle bodySm({FontWeight weight = FontWeight.w400, Color? color}) =>
      jakarta(size: 12, lineHeight: 18, tracking: 0.01, weight: weight, color: color);

  // ---- Label (Plus Jakarta Sans) ----------------------------------------
  static TextStyle labelLg({FontWeight weight = FontWeight.w600, Color? color}) =>
      jakarta(size: 14, lineHeight: 20, tracking: 0.005, weight: weight, color: color);
  static TextStyle labelMd({FontWeight weight = FontWeight.w600, Color? color}) =>
      jakarta(size: 12, lineHeight: 16, tracking: 0.02, weight: weight, color: color);
  static TextStyle labelSm({FontWeight weight = FontWeight.w700, Color? color}) =>
      jakarta(size: 11, lineHeight: 14, tracking: 0.04, weight: weight, color: color);
}
