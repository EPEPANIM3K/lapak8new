import 'package:flutter/material.dart';

/// Ikon Material Symbols Outlined (sama dengan `.material-symbols-outlined` di HTML).
/// `opticalSize` mengikuti ukuran ikon (20–48) seperti `opsz` otomatis di CSS.
/// Pakai bersama paket `material_symbols_icons`, contoh: `MsIcon(Symbols.home)`.
class MsIcon extends StatelessWidget {
  const MsIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.fill = 0,
  });

  final IconData icon;
  final double size;
  final Color? color;

  /// 0 = outline, 1 = solid (setara `font-variation-settings: 'FILL' 1`).
  final double fill;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color,
      fill: fill,
      weight: 400,
      grade: 0,
      opticalSize: size.clamp(20.0, 48.0).toDouble(),
    );
  }
}
