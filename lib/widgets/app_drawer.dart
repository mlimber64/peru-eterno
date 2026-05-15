import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../screens/premium_screen.dart';
import '../services/wikipedia_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final isPremium = context.watch<PremiumProvider>().isPremium;

    return Drawer(
      width: 300,
      backgroundColor: AppColors.marronProfundo,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Logo header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CustomPaint(painter: _MiniSunPainter()),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'PERÚ ETERNO',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cremaPergamino,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(lang),
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      color: AppColors.cremaPergamino.withOpacity(0.45),
                    ),
                  ),
                ],
              ),
            ),

            _divider(),
            const SizedBox(height: 8),

            // ── Idioma ───────────────────────────────────────────────────────
            _SectionLabel(_langLabel(lang)),
            _LanguageTile(lang: lang),

            const SizedBox(height: 12),
            _divider(),
            const SizedBox(height: 8),

            // ── Premium ──────────────────────────────────────────────────────
            _SectionLabel(_premiumLabel(lang)),
            if (isPremium)
              _InfoTile(
                icon: Icons.workspace_premium_rounded,
                label: _activePremiumLabel(lang),
                color: AppColors.ocre,
              )
            else
              _ActionTile(
                icon: Icons.star_rounded,
                label: _upgradePremiumLabel(lang),
                color: AppColors.ocre,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PremiumScreen()));
                },
              ),

            const SizedBox(height: 12),
            _divider(),
            const SizedBox(height: 8),

            // ── Caché ────────────────────────────────────────────────────────
            _SectionLabel(_cacheLabel(lang)),
            _ActionTile(
              icon: Icons.delete_sweep_rounded,
              label: _clearCacheLabel(lang),
              color: AppColors.textOnDarkMuted,
              onTap: () async {
                await WikipediaService.instance.clearCache();
                if (context.mounted) Navigator.pop(context);
              },
            ),

            const Spacer(),
            _divider(),
            // ── Footer ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Text(
                'v1.0.0 · Contenuto: Wikipedia CC BY-SA',
                style: GoogleFonts.lato(
                  fontSize: 10,
                  color: AppColors.cremaPergamino.withOpacity(0.25),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(
        color: AppColors.cremaPergamino.withOpacity(0.08),
        thickness: 1,
        indent: 24,
        endIndent: 24,
      );

  String _subtitle(String lang) => switch (lang) {
        'en' => 'Cultural encyclopedia',
        'es' => 'Enciclopedia cultural',
        _ => 'Enciclopedia culturale',
      };
  String _langLabel(String lang) => switch (lang) {
        'en' => 'LANGUAGE',
        'es' => 'IDIOMA',
        _ => 'LINGUA',
      };
  String _premiumLabel(String lang) => switch (lang) {
        _ => 'PREMIUM',
      };
  String _cacheLabel(String lang) => switch (lang) {
        'en' => 'STORAGE',
        'es' => 'ALMACENAMIENTO',
        _ => 'ARCHIVIAZIONE',
      };
  String _activePremiumLabel(String lang) => switch (lang) {
        'en' => 'Premium active ✓',
        'es' => 'Premium activo ✓',
        _ => 'Premium attivo ✓',
      };
  String _upgradePremiumLabel(String lang) => switch (lang) {
        'en' => 'Upgrade to Premium',
        'es' => 'Mejorar a Premium',
        _ => 'Passa a Premium',
      };
  String _clearCacheLabel(String lang) => switch (lang) {
        'en' => 'Clear Wikipedia cache',
        'es' => 'Limpiar caché Wikipedia',
        _ => 'Svuota cache Wikipedia',
      };
}

// ── Language tile ─────────────────────────────────────────────────────────────

class _LanguageTile extends StatelessWidget {
  final String lang;
  const _LanguageTile({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: LanguageProvider.supportedLanguages.map((l) {
          final isActive = l['code'] == lang;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                context.read<LanguageProvider>().changeLanguage(l['code']!);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.ocre.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? AppColors.ocre.withOpacity(0.6)
                        : AppColors.cremaPergamino.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(l['flag']!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text(
                      l['code']!.toUpperCase(),
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? AppColors.ocre
                            : AppColors.cremaPergamino.withOpacity(0.5),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Small reusable tiles ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Text(
        label,
        style: GoogleFonts.lato(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.cremaPergamino.withOpacity(0.35),
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: color.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cremaPergamino.withOpacity(0.85),
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.cremaPergamino.withOpacity(0.25)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoTile(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini sun painter ──────────────────────────────────────────────────────────

class _MiniSunPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3.5;

    final fill = Paint()
      ..color = AppColors.ocre.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.ocre
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, stroke);

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30.0) * (pi / 180);
      final isLong = i % 2 == 0;
      final innerR = radius + 3;
      final outerR = isLong ? radius + 10 : radius + 6;
      canvas.drawLine(
        Offset(center.dx + innerR * cos(angle), center.dy + innerR * sin(angle)),
        Offset(center.dx + outerR * cos(angle), center.dy + outerR * sin(angle)),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
