import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/language_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;

    return Scaffold(
      backgroundColor: AppColors.marronOscuro,
      body: Stack(
        children: [
          // Background subtle pattern
          Positioned.fill(
            child: CustomPaint(painter: _BackgroundPainter()),
          ),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Andean Sun Logo
                _buildLogo()
                    .animate()
                    .scale(
                      duration: 900.ms,
                      delay: 200.ms,
                      curve: Curves.elasticOut,
                    )
                    .fadeIn(duration: 500.ms, delay: 200.ms),
                const SizedBox(height: 40),
                // PERU
                Text(
                  t('splash.brand_top'),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ocre,
                    letterSpacing: 12,
                  ),
                ).animate().fadeIn(duration: 700.ms, delay: 500.ms).slideY(
                    begin: 0.2, end: 0, duration: 700.ms, delay: 500.ms),
                // ETERNO
                Text(
                  t('splash.brand_bottom'),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 52,
                    fontWeight: FontWeight.w300,
                    color: AppColors.cremaPergamino,
                    letterSpacing: 16,
                  ),
                ).animate().fadeIn(duration: 700.ms, delay: 700.ms).slideY(
                    begin: 0.2, end: 0, duration: 700.ms, delay: 700.ms),
                const SizedBox(height: 20),
                // Decorative line
                Container(
                  width: 60,
                  height: 1,
                  color: AppColors.ocre.withOpacity(0.5),
                ).animate().scaleX(duration: 600.ms, delay: 1000.ms),
                const SizedBox(height: 16),
                // Tagline
                Text(
                  t('splash.tagline'),
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    color: AppColors.cremaPergamino.withOpacity(0.65),
                    letterSpacing: 3,
                    fontWeight: FontWeight.w300,
                  ),
                ).animate().fadeIn(duration: 700.ms, delay: 1100.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ocre.withOpacity(0.6), width: 1.5),
        color: AppColors.ocre.withOpacity(0.08),
      ),
      child: Center(
        child: SizedBox(
          width: 70,
          height: 70,
          child: CustomPaint(painter: _AndeanSunPainter()),
        ),
      ),
    );
  }
}

class _AndeanSunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 4;

    final fillPaint = Paint()
      ..color = AppColors.ocre.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = AppColors.ocre
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);

    for (int i = 0; i < 16; i++) {
      final angle = (i * 22.5) * (pi / 180);
      final isLong = i % 2 == 0;
      final innerR = radius + 4;
      final outerR = isLong ? radius + 14 : radius + 9;

      final start = Offset(
        center.dx + innerR * cos(angle),
        center.dy + innerR * sin(angle),
      );
      final end = Offset(
        center.dx + outerR * cos(angle),
        center.dy + outerR * sin(angle),
      );
      canvas.drawLine(start, end, strokePaint);
    }

    // Inner cross
    final shortPaint = Paint()
      ..color = AppColors.ocre.withOpacity(0.7)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(center.dx, center.dy - radius * 0.6),
      Offset(center.dx, center.dy + radius * 0.6),
      shortPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius * 0.6, center.dy),
      Offset(center.dx + radius * 0.6, center.dy),
      shortPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ocre.withOpacity(0.04)
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
