import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import '../../routes/app_routes.dart';

/// Animated brand splash — logo scale, title reveal, soft floating orbs.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _orb;
  late final AnimationController _pulse;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _tagOpacity;
  late final Animation<double> _barOpacity;
  late final Animation<double> _barWidth;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _orb = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.55, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
    ]).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.55),
    ));

    _logoOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.28, curve: Curves.easeOut),
    );

    _titleOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.32, 0.55, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.32, 0.58, curve: Curves.easeOutCubic),
    ));

    _tagOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.48, 0.7, curve: Curves.easeOut),
    );

    _barOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.58, 0.75, curve: Curves.easeOut),
    );
    _barWidth = Tween<double>(begin: 0.15, end: 1.0).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.6, 0.95, curve: Curves.easeInOutCubic),
    ));

    _intro.forward();
    _goHome();
  }

  Future<void> _goHome() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    Get.offAllNamed(Routes.home);
  }

  @override
  void dispose() {
    _intro.dispose();
    _orb.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D47A1),
                AppUi.brandDeep,
                AppUi.brandPurple,
                Color(0xFF004D40),
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _orb,
                builder: (context, _) {
                  return CustomPaint(
                    size: size,
                    painter: _OrbPainter(
                      progress: _orb.value,
                      pulse: _pulse.value,
                    ),
                  );
                },
              ),
              SafeArea(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _intro,
                    builder: (context, _) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: _LogoBadge(pulse: _pulse.value),
                            ),
                          ),
                          const SizedBox(height: 28),
                          SlideTransition(
                            position: _titleSlide,
                            child: Opacity(
                              opacity: _titleOpacity.value,
                              child: Text(
                                'app_name'.tr,
                                style: openSansExtraBold.copyWith(
                                  color: Colors.white,
                                  fontSize: 36,
                                  letterSpacing: 0.8,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Opacity(
                            opacity: _tagOpacity.value,
                            child: Text(
                              'tagline'.tr,
                              style: openSansRegular.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 42),
                          Opacity(
                            opacity: _barOpacity.value,
                            child: SizedBox(
                              width: 140,
                              height: 3,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Stack(
                                  children: [
                                    ColoredBox(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                      child: const SizedBox.expand(),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: _barWidth.value,
                                      child: const ColoredBox(
                                        color: Colors.white,
                                        child: SizedBox.expand(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 28 + MediaQuery.paddingOf(context).bottom,
                child: FadeTransition(
                  opacity: _tagOpacity,
                  child: Text(
                    'v1.0',
                    textAlign: TextAlign.center,
                    style: openSansRegular.copyWith(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  final double pulse;

  const _LogoBadge({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final glow = 18 + (pulse * 10);
    // Icon asset already has its own rounded tile — don't clip again.
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.22 + pulse * 0.12),
            blurRadius: glow,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppUi.brandTeal.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset(
        'assets/icon.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const Icon(
          Icons.handyman_rounded,
          color: Colors.white,
          size: 56,
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final double progress;
  final double pulse;

  _OrbPainter({required this.progress, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    void orb(Offset c, double r, Color color) {
      paint.color = color;
      canvas.drawCircle(c, r, paint);
    }

    final t = progress * math.pi * 2;
    final p = 0.85 + pulse * 0.15;

    orb(
      Offset(
        size.width * 0.18 + math.sin(t) * 18,
        size.height * 0.22 + math.cos(t * 0.8) * 14,
      ),
      90 * p,
      Colors.white.withValues(alpha: 0.06),
    );
    orb(
      Offset(
        size.width * 0.82 + math.cos(t) * 16,
        size.height * 0.28 + math.sin(t * 1.1) * 20,
      ),
      110 * p,
      AppUi.brandTeal.withValues(alpha: 0.12),
    );
    orb(
      Offset(
        size.width * 0.72 + math.sin(t * 0.7) * 22,
        size.height * 0.78 + math.cos(t) * 12,
      ),
      130 * p,
      AppUi.brandPink.withValues(alpha: 0.1),
    );
    orb(
      Offset(
        size.width * 0.2 + math.cos(t * 1.2) * 10,
        size.height * 0.72 + math.sin(t * 0.9) * 16,
      ),
      70 * p,
      Colors.white.withValues(alpha: 0.05),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.pulse != pulse;
}
