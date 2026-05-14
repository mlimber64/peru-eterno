import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/world_config.dart';
import '../data/content_repository.dart';
import '../data/eras_repository.dart';
import '../models/content_item.dart';
import '../models/era_model.dart';
import '../providers/history_provider.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/cinematic_card.dart';
import 'content_detail_screen.dart';
import 'era_detail_screen.dart';
import 'premium_screen.dart';
import 'world_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _featuredController = PageController();
  Timer? _featuredTimer;
  int _featuredIndex = 0;

  final _eras = ErasRepository.allEras;

  @override
  void initState() {
    super.initState();
    _startFeaturedTimer();
  }

  @override
  void dispose() {
    _featuredTimer?.cancel();
    _featuredController.dispose();
    super.dispose();
  }

  void _startFeaturedTimer() {
    _featuredTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_featuredIndex + 1) % _eras.length;
      _featuredController.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
      setState(() => _featuredIndex = next);
    });
  }

  ContentItem get _personajeDelDia {
    final personajes = ContentRepository.personajes;
    final dayOfYear = DateTime.now().difference(
      DateTime(DateTime.now().year),
    ).inDays;
    return personajes[dayOfYear % personajes.length];
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final history = context.watch<HistoryProvider>().recentItems;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: _buildTransparentAppBar(context, lang),
      body: CustomScrollView(
        slivers: [
          // ── Hero principal (60% pantalla) ───────────────────────────────
          SliverToBoxAdapter(child: _HeroSection(lang: lang)),

          // ── Mundos ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: _worldsLabel(lang),
              lang: lang,
            ),
          ),
          SliverToBoxAdapter(child: _WorldsSection(lang: lang)),

          // ── Era Destacada ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: _featuredLabel(lang),
              lang: lang,
            ),
          ),
          SliverToBoxAdapter(
            child: _FeaturedEraSection(
              eras: _eras,
              controller: _featuredController,
              currentIndex: _featuredIndex,
              lang: lang,
              onPageChanged: (i) => setState(() => _featuredIndex = i),
            ),
          ),

          // ── Personaje del Día ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(label: _personajeLabel(lang), lang: lang),
          ),
          SliverToBoxAdapter(
            child: _PersonajeDiaSection(
                item: _personajeDelDia, lang: lang),
          ),

          // ── Continuar explorando ─────────────────────────────────────────
          if (history.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                  label: _continueLabel(lang), lang: lang),
            ),
            SliverToBoxAdapter(
              child: _ContinueSection(items: history, lang: lang),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTransparentAppBar(
      BuildContext context, String lang) {
    final isPremium = context.watch<PremiumProvider>().isPremium;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.menu_rounded,
                color: AppColors.cremaPergamino, size: 20),
          ),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      actions: [
        if (!isPremium)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _GlassButton(
              label: 'PREMIUM',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen())),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  String _worldsLabel(String lang) => switch (lang) {
        'en' => 'Explore worlds',
        'it' => 'Esplora i mondi',
        _ => 'Explorar mundos',
      };
  String _featuredLabel(String lang) => switch (lang) {
        'en' => 'Featured era',
        'it' => 'Era in evidenza',
        _ => 'Era destacada',
      };
  String _personajeLabel(String lang) => switch (lang) {
        'en' => 'Character of the day',
        'it' => 'Personaggio del giorno',
        _ => 'Personaje del día',
      };
  String _continueLabel(String lang) => switch (lang) {
        'en' => 'Continue exploring',
        'it' => 'Continua a esplorare',
        _ => 'Continuar explorando',
      };
}

// ── Hero section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final String lang;
  const _HeroSection({required this.lang});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.62;

    return SizedBox(
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3E1C00),
                  Color(0xFF1A0F0A),
                  Color(0xFF0A0605),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Subtle texture
          Positioned.fill(
            child: CustomPaint(painter: _HeroTexturePainter()),
          ),
          // Bottom fade into background
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 160,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.negoCacao],
                ),
              ),
            ),
          ),
          // Gold decorative line top-right
          Positioned(
            top: 90,
            right: 24,
            child: Container(
              width: 1,
              height: 80,
              color: AppColors.ocre.withOpacity(0.3),
            ),
          ),
          Positioned(
            top: 90,
            right: 16,
            child: Container(
              width: 1,
              height: 50,
              color: AppColors.ocre.withOpacity(0.15),
            ),
          ),
          // Content
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Eyebrow
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 1.5,
                      color: AppColors.ocre,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _eyebrow(lang),
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ocre,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 200.ms)
                    .slideX(begin: -0.1, end: 0),
                const SizedBox(height: 14),
                // Main title
                Text(
                  _mainTitle(lang),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.15,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 350.ms)
                    .slideY(begin: 0.15, end: 0),
                const SizedBox(height: 10),
                Text(
                  _subtitle(lang),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    color: AppColors.cremaPergamino.withOpacity(0.7),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 480.ms),
                const SizedBox(height: 30),
                // Buttons
                Row(
                  children: [
                    _HeroButton(
                      label: _primaryBtn(lang),
                      isPrimary: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WorldScreen(worldId: 'historia'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _HeroButton(
                      label: _secondaryBtn(lang),
                      isPrimary: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WorldScreen(worldId: 'historia'),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 800.ms, delay: 600.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _eyebrow(String lang) => switch (lang) {
        'en' => 'PERU · 5,000 YEARS',
        'it' => 'PERÙ · 5.000 ANNI',
        _ => 'PERÚ · 5,000 AÑOS',
      };
  String _mainTitle(String lang) => switch (lang) {
        'en' => '5,000 years\nof history',
        'it' => '5.000 anni\ndi storia',
        _ => '5,000 años\nde historia',
      };
  String _subtitle(String lang) => switch (lang) {
        'en' => 'Discover the soul of Peru',
        'it' => 'Scopri l\'anima del Perù',
        _ => 'Descubre el alma del Perú',
      };
  String _primaryBtn(String lang) => switch (lang) {
        'en' => 'Start journey',
        'it' => 'Inizia il viaggio',
        _ => 'Comenzar viaje',
      };
  String _secondaryBtn(String lang) => switch (lang) {
        'en' => 'Explore eras',
        'it' => 'Esplora le ere',
        _ => 'Explorar eras',
      };
}

class _HeroButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _HeroButton(
      {required this.label,
      required this.isPrimary,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ocre,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.lato(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _HeroTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ocre.withOpacity(0.03)
      ..strokeWidth = 1;
    const spacing = 36.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Worlds section ────────────────────────────────────────────────────────────

class _WorldsSection extends StatelessWidget {
  final String lang;
  const _WorldsSection({required this.lang});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: WorldConfig.worlds.length,
        itemBuilder: (context, i) {
          final world = WorldConfig.worlds[i];
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CinematicCard(
              accentColor: world.accentColor,
              title: world.titleFor(lang),
              subtitle: world.descriptionFor(lang),
              width: 160,
              height: 210,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => WorldScreen(worldId: world.id)),
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: (i * 80).ms)
                .scale(
                  begin: const Offset(0.92, 0.92),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  delay: (i * 80).ms,
                ),
          );
        },
      ),
    );
  }
}

// ── Featured era carousel ─────────────────────────────────────────────────────

class _FeaturedEraSection extends StatelessWidget {
  final List<EraModel> eras;
  final PageController controller;
  final int currentIndex;
  final String lang;
  final ValueChanged<int> onPageChanged;

  const _FeaturedEraSection({
    required this.eras,
    required this.controller,
    required this.currentIndex,
    required this.lang,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.read<LanguageProvider>().t;
    final isPremium = context.read<PremiumProvider>().isPremium;

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: eras.length,
            itemBuilder: (context, i) {
              final era = eras[i];
              final isLocked = era.isPremium && !isPremium;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CinematicCard(
                  assetImagePath:
                      era.imageAssetPath(era.imageFilenames.first),
                  accentColor: era.accentColor,
                  title: t('eras.${era.id}.title'),
                  subtitle: t('eras.${era.id}.period'),
                  badge: _badge(lang),
                  isPremium: isLocked,
                  height: 220,
                  onTap: isLocked
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PremiumScreen()))
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => EraDetailScreen(era: era))),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        SmoothPageIndicator(
          controller: controller,
          count: eras.length,
          effect: ExpandingDotsEffect(
            activeDotColor: AppColors.ocre,
            dotColor: AppColors.cremaPergamino.withOpacity(0.2),
            dotHeight: 5,
            dotWidth: 5,
            expansionFactor: 3,
            spacing: 5,
          ),
        ),
      ],
    );
  }

  String _badge(String lang) => switch (lang) {
        'en' => 'FEATURED ERA',
        'it' => 'ERA IN EVIDENZA',
        _ => 'ERA DESTACADA',
      };
}

// ── Personaje del día ─────────────────────────────────────────────────────────

class _PersonajeDiaSection extends StatelessWidget {
  final ContentItem item;
  final String lang;
  const _PersonajeDiaSection({required this.item, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ContentDetailScreen(item: item)),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF8B4513).withOpacity(0.9),
                const Color(0xFF3E1C00),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                CustomPaint(
                  painter: _DiagonalPatternPainter(const Color(0xFF8B4513)),
                  child: const SizedBox.expand(),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      // Avatar circle
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              const Color(0xFF8B4513).withOpacity(0.4),
                          border: Border.all(
                            color: AppColors.ocre.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: AppColors.ocre.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dailyLabel(lang).toUpperCase(),
                              style: GoogleFonts.lato(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ocre,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.displayName,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  _viewBioLabel(lang),
                                  style: GoogleFonts.lato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ocre,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: AppColors.ocre,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 200.ms)
            .slideY(begin: 0.1, end: 0),
      ),
    );
  }

  String _dailyLabel(String lang) => switch (lang) {
        'en' => 'Character of the day',
        'it' => 'Personaggio del giorno',
        _ => 'Personaje del día',
      };
  String _viewBioLabel(String lang) => switch (lang) {
        'en' => 'View biography',
        'it' => 'Vedi biografia',
        _ => 'Ver biografía',
      };
}

// ── Continue exploring ────────────────────────────────────────────────────────

class _ContinueSection extends StatelessWidget {
  final List<ContentItem> items;
  final String lang;
  const _ContinueSection({required this.items, required this.lang});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final era = item.category == 'era'
              ? ErasRepository.allEras
                  .cast<EraModel?>()
                  .firstWhere((e) => e?.id == item.id, orElse: () => null)
              : null;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CinematicCard(
              assetImagePath: era != null
                  ? era.imageAssetPath(era.imageFilenames.first)
                  : null,
              accentColor:
                  era?.accentColor ?? const Color(0xFF6B4226),
              title: item.displayName,
              width: 160,
              height: 130,
              onTap: () {
                if (era != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => EraDetailScreen(era: era)));
                } else {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ContentDetailScreen(item: item)));
                }
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final String lang;
  const _SectionHeader({required this.label, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 14),
      child: Row(
        children: [
          Container(width: 3, height: 18, color: AppColors.ocre),
          const SizedBox(width: 10),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.cremaPergamino,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glass button ──────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GlassButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.ocre.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.ocre.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.ocre,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

// ── Diagonal pattern painter (shared) ────────────────────────────────────────

class _DiagonalPatternPainter extends CustomPainter {
  final Color color;
  const _DiagonalPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = 1;
    const spacing = 24.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
