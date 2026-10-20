import 'package:flutter/material.dart';

/// Titik berdenyut = Tailwind `animate-ping`.
/// keyframes: 0% → 75%: scale 1→2 & opacity .75→0 (cubic-bezier(0,0,.2,1)), lalu diam.
class PingDot extends StatefulWidget {
  const PingDot({
    super.key,
    required this.pingColor,
    required this.dotColor,
    this.size = 10,
  });

  final Color pingColor;
  final Color dotColor;
  final double size;

  @override
  State<PingDot> createState() => _PingDotState();
}

class _PingDotState extends State<PingDot> with SingleTickerProviderStateMixin {
  static const _ease = Cubic(0, 0, 0.2, 1);
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = _c.value;
              final p = t < 0.75 ? _ease.transform(t / 0.75) : 1.0;
              return Transform.scale(
                scale: 1 + p,
                child: Opacity(
                  opacity: 0.75 * (1 - p),
                  child: Container(
                    decoration: BoxDecoration(
                        color: widget.pingColor, shape: BoxShape.circle),
                  ),
                ),
              );
            },
          ),
          Container(
            decoration:
                BoxDecoration(color: widget.dotColor, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

/// Loncat naik-turun = Tailwind `animate-bounce`.
/// 0%/100%: naik 25% tinggi elemen (cubic-bezier(.8,0,1,1)), 50%: posisi normal (cubic-bezier(0,0,.2,1)).
/// [travel] = 25% dari tinggi elemen dalam px.
class BounceEffect extends StatefulWidget {
  const BounceEffect({super.key, required this.child, required this.travel});

  final Widget child;
  final double travel;

  @override
  State<BounceEffect> createState() => _BounceEffectState();
}

class _BounceEffectState extends State<BounceEffect>
    with SingleTickerProviderStateMixin {
  static const _accel = Cubic(0.8, 0, 1, 1);
  static const _decel = Cubic(0, 0, 0.2, 1);
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _dy(double t) {
    if (t < 0.5) {
      return -widget.travel * (1 - _accel.transform(t / 0.5));
    }
    return -widget.travel * _decel.transform((t - 0.5) / 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) =>
          Transform.translate(offset: Offset(0, _dy(_c.value)), child: child),
    );
  }
}
