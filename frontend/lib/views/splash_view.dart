import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'widgets/design_system.dart';

/// Covers the workspace while it loads, then reveals it without adding a route.
class SplashView extends StatefulWidget {
  final Widget child;
  const SplashView({super.key, required this.child});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _finished = false;
  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2400),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _finished = true);
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      if (_reduceMotion) {
        _controller.duration = const Duration(milliseconds: 150);
      }
      _controller.forward();
    } else if (_reduceMotion && !_finished) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeSemantics(
        excluding: !_finished,
        child: IgnorePointer(ignoring: !_finished, child: widget.child),
      ),
      if (!_finished)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final entrance = _reduceMotion
                ? 1.0
                : Curves.easeOutCubic.transform((t / .36).clamp(0.0, 1.0));
            final fade =
                1 -
                Curves.easeInOut.transform(((t - .82) / .18).clamp(0.0, 1.0));
            return Opacity(
              opacity: fade,
              child: Semantics(
                label:
                    'CellScope. Medical data, made clear. Opening workspace.',
                excludeSemantics: true,
                child: Material(
                  key: const ValueKey('cellscope-splash'),
                  color: emeraldDarkest,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -.25),
                        radius: 1.05,
                        colors: [
                          Color(0xFF0B4937),
                          Color(0xFF021B14),
                          Color(0xFF01110D),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxHeight < 480;
                          return Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Opacity(
                                    opacity: entrance,
                                    child: Transform.scale(
                                      scale: .88 + .12 * entrance,
                                      child: CustomPaint(
                                        painter: _CellPainter(
                                          _reduceMotion ? .5 : t,
                                        ),
                                        size: Size.square(compact ? 132 : 224),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 16 : 32),
                                  Opacity(
                                    opacity: entrance,
                                    child: Transform.translate(
                                      offset: Offset(0, 16 * (1 - entrance)),
                                      child: Column(
                                        children: [
                                          const Text(
                                            'CellScope',
                                            style: TextStyle(
                                              fontSize: 38,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -1.5,
                                              color: Color(0xFFF0FFF8),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            'Medical data, made clear.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Color(0xFF9CCDB9),
                                              letterSpacing: .4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 24 : 48),
                                  SizedBox(
                                    width: 112,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: t,
                                        minHeight: 3,
                                        color: emeraldBright,
                                        backgroundColor: const Color(
                                          0xFF184334,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'EXPLORE • UNDERSTAND • DISCOVER',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9,
                                      letterSpacing: 2,
                                      color: Color(0xFF79AA95),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    ],
  );
}

class _CellPainter extends CustomPainter {
  final double progress;
  _CellPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      center,
      r * .82,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x4034D399), Color(0x0034D399)],
        ).createShader(Rect.fromCircle(center: center, radius: r * .82)),
    );
    for (final scale in [.72, .94]) {
      canvas.drawCircle(
        center,
        r * scale,
        Paint()
          ..color = const Color(0x3346D9A4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    final angle = progress * math.pi * 1.4;
    for (var i = 0; i < 6; i++) {
      final a = angle + i * math.pi / 3;
      final orbit = i.isEven ? .72 : .94;
      final point = center + Offset(math.cos(a), math.sin(a)) * (r * orbit);
      canvas.drawCircle(
        point,
        i.isEven ? 4 : 2.5,
        Paint()..color = const Color(0xFF6EE7B7),
      );
    }
    final membrane = Path();
    for (var i = 0; i <= 100; i++) {
      final a = i / 100 * math.pi * 2;
      final radius = r * (.49 + .035 * math.sin(3 * a + angle));
      final point = center + Offset(math.cos(a), math.sin(a)) * radius;
      if (i == 0) {
        membrane.moveTo(point.dx, point.dy);
      } else {
        membrane.lineTo(point.dx, point.dy);
      }
    }
    membrane.close();
    canvas.drawPath(
      membrane,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF52E5AB), Color(0xFF087D59)],
        ).createShader(Rect.fromCircle(center: center, radius: r * .5)),
    );
    canvas.drawPath(
      membrane,
      Paint()
        ..color = const Color(0xAA9DFFCE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final nucleus = center + Offset(-r * .04, -r * .02);
    canvas.drawCircle(
      nucleus,
      r * .20,
      Paint()..color = const Color(0xFF034D36),
    );
    canvas.drawCircle(
      nucleus + Offset(-r * .035, -r * .04),
      r * .07,
      Paint()..color = const Color(0xFF9EF5CD),
    );
    for (var i = 0; i < 3; i++) {
      final a = i * 2.1 + .4;
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * r * .34,
        r * .035,
        Paint()..color = const Color(0x999CFFD2),
      );
    }
  }

  @override
  bool shouldRepaint(_CellPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
