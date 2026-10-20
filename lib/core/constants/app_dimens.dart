import 'package:flutter/painting.dart';

/// Token spacing Tailwind khusus desain ini.
class AppSpacing {
  AppSpacing._();
  static const double xxs = 4; // space-xxs
  static const double xs = 8; // space-xs
  static const double sm = 12; // space-sm
  static const double md = 16; // space-md
  static const double lg = 20; // space-lg
  static const double xl = 24; // space-xl
  static const double x2l = 32; // space-2xl
  static const double x3l = 40; // space-3xl
  static const double x4l = 48; // space-4xl
  static const double mobileGutter = 16;
  static const double bottomNavHeight = 72;
  static const double touchTargetMin = 44;
}

/// borderRadius desain: DEFAULT 1rem, lg 2rem, xl 3rem.
class AppRadius {
  AppRadius._();
  static const double base = 16;
  static const double lg = 32;
  static const double xl = 48;
  static const double full = 9999;
}

/// Bayangan Tailwind (sm, md, xl) dengan nilai yang sama persis.
class AppShadows {
  AppShadows._();

  static const sm = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  static const md = [
    BoxShadow(
        color: Color(0x1A000000),
        offset: Offset(0, 4),
        blurRadius: 6,
        spreadRadius: -1),
    BoxShadow(
        color: Color(0x1A000000),
        offset: Offset(0, 2),
        blurRadius: 4,
        spreadRadius: -2),
  ];

  static const xl = [
    BoxShadow(
        color: Color(0x1A000000),
        offset: Offset(0, 20),
        blurRadius: 25,
        spreadRadius: -5),
    BoxShadow(
        color: Color(0x1A000000),
        offset: Offset(0, 8),
        blurRadius: 10,
        spreadRadius: -6),
  ];
}
