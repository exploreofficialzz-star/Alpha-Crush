import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _tileCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textSlide;
  late Animation<double> _textFade;
  late Animation<double> _tileRotate;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _tileCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);

    _logoScale = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn)
        .drive(Tween(begin: 0.0, end: 1.0));
    _textSlide = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic)
        .drive(Tween(begin: 40.0, end: 0.0));
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn)
        .drive(Tween(begin: 0.0, end: 1.0));
    _tileRotate = _tileCtrl.drive(Tween(begin: 0.0, end: 2 * math.pi));
    _pulse = _pulseCtrl.drive(Tween(begin: 0.95, end: 1.05));

    _logoCtrl.forward().then((_) {
      _textCtrl.forward();
    });

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _tileCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D0D1A),
              Color(0xFF1A0533),
              Color(0xFF0D1A33),
            ],
          ),
        ),
        child: Stack(
          children: [
            // ── Floating candy tiles background ──
            ...List.generate(12, (i) => _floatingTile(i, size)),

            // ── Main content ──
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo card
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _pulse,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6A11CB).withOpacity(0.6),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'AC',
                              style: TextStyle(
                                fontSize: 54,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ALPHA text
                  AnimatedBuilder(
                    animation: _textCtrl,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, _textSlide.value),
                      child: Opacity(
                        opacity: _textFade.value,
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
                                colors: [Colors.white, Color(0xFFB388FF)],
                              ).createShader(bounds),
                              child: const Text(
                                'ALPHA',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 10,
                                ),
                              ),
                            ),
                            ShaderMask(
                              shaderCallback: (bounds) =>
                                  const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                              ).createShader(bounds),
                              child: const Text(
                                'CRUSH',
                                style: TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rebuild. Crush. Win.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white.withOpacity(0.55),
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 52),

                  // Loading dots
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        final v = (_pulseCtrl.value * 3 - i).clamp(0.0, 1.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.3 + v * 0.7),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Text(
                    'by chAs',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.30),
                      fontSize: 13,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _tileLetters = ['A', 'B', 'C', 'E', 'K', 'M', 'O', 'S', 'T', 'Z', 'R', 'Y'];
  static const _tileColors = [
    Color(0xFFE53935), Color(0xFF1565C0), Color(0xFFFF8F00), Color(0xFF6A1B9A),
    Color(0xFF00897B), Color(0xFFF4511E), Color(0xFF2E7D32), Color(0xFFAD1457),
    Color(0xFF0097A7), Color(0xFF558B2F), Color(0xFFC62828), Color(0xFF827717),
  ];

  Widget _floatingTile(int i, Size screen) {
    final positions = [
      Offset(0.08, 0.12), Offset(0.85, 0.08), Offset(0.15, 0.78),
      Offset(0.82, 0.72), Offset(0.55, 0.04), Offset(0.03, 0.45),
      Offset(0.92, 0.38), Offset(0.44, 0.88), Offset(0.70, 0.55),
      Offset(0.28, 0.30), Offset(0.62, 0.22), Offset(0.10, 0.60),
    ];
    final p = positions[i % positions.length];
    return Positioned(
      left: p.dx * screen.width - 20,
      top: p.dy * screen.height - 20,
      child: AnimatedBuilder(
        animation: _tileCtrl,
        builder: (_, __) {
          final angle = (_tileRotate.value + i * math.pi / 6) % (2 * math.pi);
          return Transform.rotate(
            angle: angle * 0.3,
            child: Opacity(
              opacity: 0.08 + (math.sin(angle + i) * 0.04).abs(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _tileColors[i % _tileColors.length].withOpacity(0.7),
                ),
                child: Center(
                  child: Text(
                    _tileLetters[i % _tileLetters.length],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
