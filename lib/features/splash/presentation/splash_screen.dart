import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _text = 'LAPAK8';
  static const _pIndex = 2;
  static const _dotX = 0.55;
  static const _dotY = 0.42;
  static const _dotRadius = 7.0;
  static const _textStyle = TextStyle(
    color: Colors.white,
    fontSize: 44,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
    height: 1,
  );

  late final AnimationController _controller;
  late final Animation<double> _textFade;
  late final Animation<double> _dotScale;
  late final Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.2, curve: Curves.easeIn),
    );
    _dotScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.4, curve: Curves.easeOutBack),
    );
    _expand = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1, curve: Curves.easeInOutCubic),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.go(
          authProvider.sudahLogin
              ? (authProvider.isAdminAtauStaf ? '/admin/dashboard' : '/')
              : '/welcome',
        );
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashNavy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final textPainter = TextPainter(
            text: const TextSpan(text: _text, style: _textStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          final origin = Offset(
            (size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2,
          );
          final letterBox = textPainter
              .getBoxesForSelection(
                const TextSelection(
                  baseOffset: _pIndex,
                  extentOffset: _pIndex + 1,
                ),
              )
              .first;
          final center = Offset(
            origin.dx +
                letterBox.left +
                (letterBox.right - letterBox.left) * _dotX,
            origin.dy +
                letterBox.top +
                (letterBox.bottom - letterBox.top) * _dotY,
          );
          final maxRadius = math.sqrt(
            math.pow(math.max(center.dx, size.width - center.dx), 2) +
                math.pow(math.max(center.dy, size.height - center.dy), 2),
          );

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Stack(
              children: [
                Center(
                  child: Opacity(
                    opacity: _textFade.value,
                    child: const Text(_text, style: _textStyle),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SplashCirclePainter(
                      center: center,
                      dotScale: _dotScale.value,
                      expand: _expand.value,
                      maxRadius: maxRadius,
                      baseRadius: _dotRadius,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SplashCirclePainter extends CustomPainter {
  const _SplashCirclePainter({
    required this.center,
    required this.dotScale,
    required this.expand,
    required this.maxRadius,
    required this.baseRadius,
  });

  final Offset center;
  final double dotScale;
  final double expand;
  final double maxRadius;
  final double baseRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (dotScale <= 0) return;

    final radius = baseRadius * dotScale + expand * maxRadius;
    if (expand > 0) {
      canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.splashRing
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashCirclePainter oldDelegate) =>
      oldDelegate.dotScale != dotScale ||
      oldDelegate.expand != expand ||
      oldDelegate.center != center;
}
