import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../core/constants/app_colors.dart';
import '../providers/language_provider.dart';

/// Primer arranque: tres pantallas que explican qué es la app, dejan elegir
/// idioma y presentan el hábito diario.
///
/// Antes se caía directamente en la Home, con lo que un usuario nuevo veía
/// una portada bonita sin entender qué se espera de él ni que hay una racha
/// que mantener. Estas tres pantallas son donde se decide si se queda.
///
/// La segunda pantalla es idioma a propósito: la detección automática acierta
/// casi siempre, pero cuando falla (un teléfono en francés, un móvil
/// compartido) el usuario se queda con una app que no entiende y sin saber
/// que se puede cambiar.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String routePath = '/onboarding';
  static const String _kSeen = 'onboarding_seen';

  /// `true` si nunca se ha completado (ni saltado) el onboarding.
  static Future<bool> shouldShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_kSeen) ?? false);
    } catch (_) {
      // Ante la duda, no molestar: mejor saltárselo que mostrarlo dos veces.
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSeen, true);
    } catch (_) {
      // Si no se puede persistir, se volverá a ver una vez más. Inofensivo.
    }
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingScreen.markSeen();
    if (!mounted) return;
    context.go('/home');
  }

  void _next() {
    if (_page >= _pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final isLast = _page == _pageCount - 1;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  t('onboarding.skip'),
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cremaPergamino.withOpacity(0.45),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _OnboardingPage(
                    icon: Icons.auto_stories_rounded,
                    eyebrow: t('onboarding.p1_eyebrow'),
                    title: t('onboarding.p1_title'),
                    body: t('onboarding.p1_body'),
                  ),
                  _LanguagePage(t: t),
                  _OnboardingPage(
                    icon: Icons.local_fire_department_rounded,
                    eyebrow: t('onboarding.p3_eyebrow'),
                    title: t('onboarding.p3_title'),
                    body: t('onboarding.p3_body'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _pageCount,
                    effect: ExpandingDotsEffect(
                      dotHeight: 7,
                      dotWidth: 7,
                      expansionFactor: 3.5,
                      spacing: 6,
                      dotColor: AppColors.cremaPergamino.withOpacity(0.18),
                      activeDotColor: AppColors.ocre,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ocre,
                        foregroundColor: AppColors.negoCacao,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        isLast ? t('onboarding.start') : t('onboarding.next'),
                        style: GoogleFonts.lato(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
}

// ── Páginas ───────────────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;

  const _OnboardingPage({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.ocre.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ocre.withOpacity(0.3)),
            ),
            child: Icon(icon, size: 36, color: AppColors.ocre),
          ),
          const SizedBox(height: 32),
          Text(
            eyebrow.toUpperCase(),
            style: GoogleFonts.lato(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: AppColors.ocre,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.cremaPergamino,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: GoogleFonts.lato(
              fontSize: 15.5,
              color: AppColors.cremaPergamino.withOpacity(0.65),
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

/// Segunda pantalla: confirmar o corregir el idioma detectado.
class _LanguagePage extends StatelessWidget {
  final String Function(String) t;

  const _LanguagePage({required this.t});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LanguageProvider>().currentLanguage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.ocre.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ocre.withOpacity(0.3)),
            ),
            child: const Icon(Icons.translate_rounded,
                size: 36, color: AppColors.ocre),
          ),
          const SizedBox(height: 32),
          Text(
            t('onboarding.p2_eyebrow').toUpperCase(),
            style: GoogleFonts.lato(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: AppColors.ocre,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t('onboarding.p2_title'),
            style: GoogleFonts.playfairDisplay(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.cremaPergamino,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 24),
          for (final language in LanguageProvider.supportedLanguages)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LanguageOption(
                code: language['code']!,
                label: language['label']!,
                flag: language['flag']!,
                selected: language['code'] == current,
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String code;
  final String label;
  final String flag;
  final bool selected;

  const _LanguageOption({
    required this.code,
    required this.label,
    required this.flag,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.ocre.withOpacity(0.15)
          : AppColors.marronProfundo,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.read<LanguageProvider>().changeLanguage(code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.ocre.withOpacity(0.6)
                  : AppColors.cremaPergamino.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.ocre
                        : AppColors.cremaPergamino.withOpacity(0.7),
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    size: 20, color: AppColors.ocre),
            ],
          ),
        ),
      ),
    );
  }
}
