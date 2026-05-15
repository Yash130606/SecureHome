import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../providers/app_provider.dart';
import '../../widgets/s_button.dart';
import '../home/main_shell.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_screen.dart';

class _Page {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> tags;

  const _Page({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tags,
  });
}

const _pages = [
  _Page(
    title: "Monitor Your Home",
    subtitle:
        "View live feeds from all cameras and keep an eye on every corner of your property.",
    icon: Icons.home_outlined,
    tags: ["Live Monitoring", "HD Cameras", "Secure Access"],
  ),
  _Page(
    title: "AI Motion Detection",
    subtitle: "Advanced AI detects people and unusual activity instantly.",
    icon: Icons.person_search_outlined,
    tags: ["AI Detection", "Smart Alerts", "Instant Notification"],
  ),
  _Page(
    title: "Cloud Recording",
    subtitle:
        "Every moment is securely stored so you never miss important events.",
    icon: Icons.cloud_outlined,
    tags: ["Cloud Backup", "Download Clips", "Encrypted Storage"],
  ),
  _Page(
    title: "Stay Protected",
    subtitle:
        "Receive instant alerts and stay connected to your home from anywhere.",
    icon: Icons.notifications_active_outlined,
    tags: ["Real-time Alerts", "24/7 Monitoring", "Remote Access"],
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _current = 0;

  late AnimationController _iconFloat;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();

    _iconFloat = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnim = Tween(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _iconFloat, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _iconFloat.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < 3) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() async {
    await context.read<AppProvider>().completeOnboarding();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_current];

    return Scaffold(
      body: Stack(
        children: [
          /// BACKGROUND
          const AnimatedSecurityBackground(),

          SafeArea(
            child: Column(
              children: [
                /// STEP INDICATOR
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Text(
                        "Step ${_current + 1} / 4",
                        style: AppText.bodyM(
                                color: const Color.fromARGB(255, 117, 241, 227))
                            .copyWith(
                                fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (_current < 3)
                        GestureDetector(
                          onTap: _finish,
                          child: Text(
                            "Skip",
                            style: AppText.bodyM(color: AppColors.brand)
                                .copyWith(
                                    fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        )
                    ],
                  ),
                ),

                /// PAGE VIEW
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: _pages.length,
                    onPageChanged: (i) {
                      setState(() => _current = i);
                    },
                    itemBuilder: (_, i) {
                      final p = _pages[i];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            /// FLOATING ICON
                            AnimatedBuilder(
                              animation: _floatAnim,
                              builder: (_, __) {
                                return Transform.translate(
                                  offset: Offset(0, _floatAnim.value),
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      gradient: AppColors.brandGradient,
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              AppColors.brand.withOpacity(0.5),
                                          blurRadius: 40,
                                        )
                                      ],
                                    ),
                                    child: Icon(
                                      p.icon,
                                      color: Colors.white,
                                      size: 46,
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 40),

                            /// TITLE
                            Text(
                              p.title,
                              textAlign: TextAlign.center,
                              style: AppText.hero(),
                            ),

                            const SizedBox(height: 18),

                            /// SUBTITLE
                            Text(
                              p.subtitle,
                              textAlign: TextAlign.center,
                              style: AppText.bodyL(),
                            ),

                            const SizedBox(height: 24),

                            /// TAGS
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: p.tags
                                  .map((e) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: AppColors.brand
                                                .withOpacity(0.4),
                                          ),
                                        ),
                                        child: Text(
                                          e,
                                          style: AppText.label(
                                              color: AppColors.brand),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                /// PAGE INDICATOR
                SmoothPageIndicator(
                  controller: _pageCtrl,
                  count: 4,
                  effect: ExpandingDotsEffect(
                    dotHeight: 6,
                    dotWidth: 6,
                    activeDotColor: AppColors.brand,
                    dotColor: AppColors.textMuted,
                    expansionFactor: 4,
                  ),
                ),

                const SizedBox(height: 26),

                /// BUTTON
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _current == 3
                      ? SButton(
                          label: "Start Protecting Your Home",
                          icon: Icons.security,
                          onTap: _finish,
                        )
                      : SButton(
                          label: "Continue",
                          icon: Icons.arrow_forward,
                          onTap: _next,
                        ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// BACKGROUND ANIMATION

class AnimatedSecurityBackground extends StatefulWidget {
  const AnimatedSecurityBackground({super.key});

  @override
  State<AnimatedSecurityBackground> createState() =>
      _AnimatedSecurityBackgroundState();
}

class _AnimatedSecurityBackgroundState extends State<AnimatedSecurityBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return CustomPaint(
          painter: SecurityGridPainter(controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class SecurityGridPainter extends CustomPainter {
  final double progress;

  SecurityGridPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.brand.withOpacity(0.05)
      ..strokeWidth = 1;

    const spacing = 50.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final particlePaint = Paint()..color = AppColors.brand.withOpacity(0.6);

    final random = Random(1);

    for (int i = 0; i < 45; i++) {
      final x = random.nextDouble() * size.width;
      final y =
          ((random.nextDouble() * size.height) + progress * 100) % size.height;

      canvas.drawCircle(
        Offset(x, y),
        random.nextDouble() * 2.5 + 1,
        particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => true;
}
