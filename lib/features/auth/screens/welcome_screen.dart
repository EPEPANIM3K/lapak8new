import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Kunci untuk mengukur posisi titik biru secara akurat.
  final GlobalKey _dotKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();

  Offset _circleOrigin = Offset.zero;
  bool _originReady = false;

  static const Color navy = Color(0xFF0F172A);
  static const Color blue = Color(0xFF2563EB);

  late Animation<double> _reveal;
  late Animation<double> _welcomeFade;
  late Animation<Offset> _welcomeSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );

    // Lingkaran mulai membesar dari posisi titik biru logo
    _reveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.30,
        0.82,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Welcome screen muncul setelah lingkaran menutupi layar
    _welcomeFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.80,
        1.0,
        curve: Curves.easeOut,
      ),
    );

    _welcomeSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.80,
          1.0,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    // Ukur posisi titik setelah layout pertama selesai,
    // sebelum animasi dijalankan.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateCircleOrigin();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Menghitung pusat titik biru pada koordinat Stack.
  /// Animasi hanya dimulai setelah koordinat berhasil diperoleh.
  void _updateCircleOrigin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final dotContext = _dotKey.currentContext;
      final stackContext = _stackKey.currentContext;

      if (dotContext == null || stackContext == null) return;

      final dotBox = dotContext.findRenderObject() as RenderBox;
      final stackBox = stackContext.findRenderObject() as RenderBox;

      final globalCenter = dotBox.localToGlobal(
        dotBox.size.center(Offset.zero),
      );

      setState(() {
        _circleOrigin = stackBox.globalToLocal(globalCenter);
        _originReady = true;
      });

      // Animasi baru mulai setelah posisi titik tersedia.
      _controller.forward();
    });
  }

  void _getStarted() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          final scale = width / 402;
          final fontSize = 64 * scale;

          // Diameter cukup besar untuk menutupi seluruh layar.
          final maxDiameter =
              math.sqrt(width * width + height * height) * 2.2;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _reveal.value;

              final diameter = 18 * scale +
                  (maxDiameter - 18 * scale) * progress;

              final circleColor = Color.lerp(
                blue,
                Colors.white,
                Curves.easeInOut.transform(progress),
              )!;

              return Stack(
                key: _stackKey,
                clipBehavior: Clip.hardEdge,
                children: [
                  // BACKGROUND SPLASH
                  Positioned.fill(
                    child: Container(color: navy),
                  ),

                  // LOGO LAPAK8 + TITIK BIRU
                  Center(
                    child: Opacity(
                      opacity: (1 - progress * 0.9).clamp(0.0, 1.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'LAPAK8',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: fontSize,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.45 * scale,
                            ),
                          ),

                          Padding(
                            padding: EdgeInsets.only(
                              left: 5 * scale,
                              bottom: 11 * scale,
                            ),
                            child: Container(
                              key: _dotKey,
                              width: 11 * scale,
                              height: 11 * scale,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // LINGKARAN EKSPANSI — pusatnya mengikuti titik biru
                  if (_originReady)
                    Positioned(
                      left: _circleOrigin.dx - diameter / 2,
                      top: _circleOrigin.dy - diameter / 2,
                      width: diameter,
                      height: diameter,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: circleColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),

                  // WELCOME SCREEN
                  if (progress > 0.75)
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: _welcomeFade.value < 1,
                        child: Opacity(
                          opacity: _welcomeFade.value,
                          child: SlideTransition(
                            position: _welcomeSlide,
                            child: _buildWelcome(scale),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWelcome(double scale) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64 * scale,
            height: 64 * scale,
            decoration: BoxDecoration(
              color: blue,
              borderRadius: BorderRadius.circular(14 * scale),
            ),
            child: Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 38 * scale,
            ),
          ),

          SizedBox(height: 12 * scale),

          Text(
            'WELCOME',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20 * scale,
              fontWeight: FontWeight.w800,
              color: navy,
            ),
          ),

          SizedBox(height: 3 * scale),

          Text(
            'LAPAK8',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 13 * scale,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),

          SizedBox(height: 24 * scale),

          SizedBox(
            width: 130 * scale,
            height: 36 * scale,
            child: ElevatedButton(
              onPressed: _getStarted,
              style: ElevatedButton.styleFrom(
                backgroundColor: blue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: const StadiumBorder(),
              ),
              child: Text(
                'Get Started',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 11 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}