import 'package:flutter/painting.dart';

/// Semua warna diambil 1:1 dari `tailwind.config` desain (Figma → HTML).
class AppColors {
  AppColors._();

  // Primary
  static const primary = Color(0xFF0037B0);
  static const primaryContainer = Color(0xFF1D4ED8);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFFCAD3FF);
  static const primaryFixed = Color(0xFFDCE1FF);
  static const primaryFixedDim = Color(0xFFB7C4FF);
  static const onPrimaryFixed = Color(0xFF001551);
  static const onPrimaryFixedVariant = Color(0xFF0039B5);
  static const inversePrimary = Color(0xFFB7C4FF);
  static const surfaceTint = Color(0xFF2151DA);

  // Secondary
  static const secondary = Color(0xFF505F76);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFD0E1FB);
  static const onSecondaryContainer = Color(0xFF54647A);
  static const secondaryFixed = Color(0xFFD3E4FE);
  static const secondaryFixedDim = Color(0xFFB7C8E1);
  static const onSecondaryFixed = Color(0xFF0B1C30);
  static const onSecondaryFixedVariant = Color(0xFF38485D);

  // Tertiary
  static const tertiary = Color(0xFF004F35);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFF006A48);
  static const onTertiaryContainer = Color(0xFF60EEB1);
  static const tertiaryFixed = Color(0xFF6FFBBE);
  static const tertiaryFixedDim = Color(0xFF4EDEA3);
  static const onTertiaryFixed = Color(0xFF002113);
  static const onTertiaryFixedVariant = Color(0xFF005236);

  // Error
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Surface
  static const background = Color(0xFFFAF8FF);
  static const onBackground = Color(0xFF131B2E);
  static const surface = Color(0xFFFAF8FF);
  static const surfaceBright = Color(0xFFFAF8FF);
  static const surfaceDim = Color(0xFFD2D9F4);
  static const surfaceVariant = Color(0xFFDAE2FD);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF2F3FF);
  static const surfaceContainer = Color(0xFFEAEDFF);
  static const surfaceContainerHigh = Color(0xFFE2E7FF);
  static const surfaceContainerHighest = Color(0xFFDAE2FD);
  static const onSurface = Color(0xFF131B2E);
  static const onSurfaceVariant = Color(0xFF434655);
  static const inverseSurface = Color(0xFF283044);
  static const inverseOnSurface = Color(0xFFEEF0FF);
  static const outline = Color(0xFF747686);
  static const outlineVariant = Color(0xFFC4C5D7);

  // Warna bawaan Tailwind yang dipakai kartu "Item Populer"
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate900 = Color(0xFF0F172A);
  static const slateBorder = Color(0xFFE2E8F0); // #e2e8f0
  static const emerald500 = Color(0xFF10B981);
  static const white = Color(0xFFFFFFFF);
}

extension ColorFade on Color {
  /// Setara utilitas Tailwind `bg-xxx/70` (opacity 0..1).
  Color fade(double opacity) => withAlpha((opacity * 255).round());
}
