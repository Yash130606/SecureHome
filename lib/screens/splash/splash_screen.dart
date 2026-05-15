// lib/screens/splash/splash_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart'; // ✅ NEW
import '../onboarding/onboarding_screen.dart';
import '../home/main_shell.dart';
import '../auth/login_screen.dart'; // ✅ NEW


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _progressCtrl;

  late Animation<double> _radarRotation;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _progressAnim;

  bool _navigated = false;

  static const _returningDuration = Duration(milliseconds: 2500);
  static const _newUserDuration = Duration(milliseconds: 5000);

  @override
  void initState() {
    super.initState();

    _radarCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();

    _radarRotation = Tween<double>(begin: 0, end: 2 * pi).animate(_radarCtrl);

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();

    _logoOpacity = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn);
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack),
    );

    _progressCtrl = AnimationController(vsync: this, duration: _newUserDuration)
      ..forward();

    _progressAnim =
        CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut);

    _scheduleNavigation();
  }

  Future<void> _scheduleNavigation() async {
    final prov = context.read<AppProvider>();
    final isReturning = prov.onboardingDone;

    final delay = isReturning ? _returningDuration : _newUserDuration;

    if (isReturning) {
      _progressCtrl.duration = _returningDuration;
      _progressCtrl
        ..reset()
        ..forward();
    }

    await Future.delayed(delay);
    if (mounted && !_navigated) _navigate();
  }

  void _navigate() {
    if (_navigated) return;
    _navigated = true;

    final appProvider = context.read<AppProvider>();
    final authProvider = context.read<AuthProvider>();

    if (!appProvider.onboardingDone) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else if (!authProvider.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _logoCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        CustomPaint(painter: _GridPainter(), size: Size.infinite),
        Center(
          child: AnimatedBuilder(
            animation: _radarRotation,
            builder: (_, __) => CustomPaint(
              painter: _RadarPainter(rotation: _radarRotation.value),
              size: const Size(240, 240),
            ),
          ),
        ),
        Center(
          child: AnimatedBuilder(
            animation: _logoCtrl,
            builder: (_, __) => Opacity(
              opacity: _logoOpacity.value,
              child: Transform.scale(
                scale: _logoScale.value,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.brandGradient,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.brand.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 4)
                      ],
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: AppColors.textOnBrand, size: 38),
                  ),
                  const SizedBox(height: 20),
                  Text('SECUREHOME',
                      style: AppText.h1(color: AppColors.textPrimary)
                          .copyWith(letterSpacing: 4)),
                  const SizedBox(height: 8),
                  Text('AI Security System',
                      style: AppText.bodyM(color: AppColors.brand)),
                  const SizedBox(height: 8),
                  Text('Initializing...', style: AppText.caption()),
                ]),
              ),
            ),
          ),
        ),
        Positioned(
          left: 48,
          right: 48,
          bottom: 80,
          child: Column(children: [
            AnimatedBuilder(
              animation: _progressAnim,
              builder: (_, __) => Column(children: [
                Text(
                  _bootMessage(_progressAnim.value),
                  style: AppText.mono(
                      color: AppColors.brand.withOpacity(0.6), size: 10),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: AppColors.bgHighlight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressAnim.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.brand.withOpacity(0.5),
                              blurRadius: 6)
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  String _bootMessage(double progress) {
    if (progress < 0.2) return 'Initializing security modules...';
    if (progress < 0.4) return 'Connecting to camera network...';
    if (progress < 0.6) return 'Loading AI detection engine...';
    if (progress < 0.8) return 'Syncing alert database...';
    return 'System ready.';
  }
}

// ── PAINTERS ─────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brand.withOpacity(0.03)
      ..strokeWidth = 1;

    const spacing = 50.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _RadarPainter extends CustomPainter {
  final double rotation;

  _RadarPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Rings
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center,
        radius * i / 3,
        Paint()
          ..color = AppColors.brand.withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.brand.withOpacity(0.25),
        ],
        startAngle: 0,
        endAngle: pi / 2,
        transform: GradientRotation(rotation),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, sweepPaint);

    // Sweep line
    final linePaint = Paint()
      ..color = AppColors.brand.withOpacity(0.6)
      ..strokeWidth = 1.5;

    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * cos(rotation),
        center.dy + radius * sin(rotation),
      ),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.rotation != rotation;
}