import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/world_config.dart';
import '../core/navigation/app_navigation.dart';
import '../data/content_repository.dart';
import '../data/eras_repository.dart';
import '../data/historia_stages_repository.dart';
import '../models/content_item.dart';
import '../models/era_model.dart';
import '../models/historia_article.dart';
import '../models/historia_stage.dart';
import '../providers/history_provider.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/reading_progress_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/caral_placeholder.dart';
import '../widgets/cinematic_card.dart';
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
    final dayOfYear = DateTime.now()
        .difference(
          DateTime(DateTime.now().year),
        )
        .inDays;
    return personajes[dayOfYear % personajes.length];
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final history = context.watch<HistoryProvider>().recentItems;
    final rp = context.watch<ReadingProgressProvider>();

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: _buildTransparentAppBar(context, lang),
      body: CustomScrollView(
        slivers: [
          // ── Hero principal (60% pantalla) ───────────────────────────────
          SliverToBoxAdapter(child: _HeroSection(lang: lang)),

          // ── Continua il tuo viaggio ─────────────────────────────────────
          if (rp.hasLastArticle) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                  label: context
                      .read<LanguageProvider>()
                      .t('home.continue_journey'),
                  lang: lang),
            ),
            SliverToBoxAdapter(
              child: _JourneyCard(
                articleId: rp.lastArticleId!,
                stageId: rp.lastStageId ?? '',
                progress: rp.lastProgress,
                lang: lang,
              ),
            ),
          ],

          // ── Intro Perú ──────────────────────────────────────────────────
          SliverToBoxAdapter(child: _PeruIntroSection(lang: lang)),

          // ── Mundos ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: context.read<LanguageProvider>().t('home.worlds'),
              lang: lang,
            ),
          ),
          SliverToBoxAdapter(child: _WorldsSection(lang: lang)),

          // ── Era Destacada ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              label: context.read<LanguageProvider>().t('home.featured'),
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
            child: _SectionHeader(
                label:
                    context.read<LanguageProvider>().t('home.character_of_day'),
                lang: lang),
          ),
          SliverToBoxAdapter(
            child: _PersonajeDiaSection(item: _personajeDelDia, lang: lang),
          ),

          // ── Historial reciente de Historia ───────────────────────────────
          if (rp.history.length > 1) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                  label:
                      context.read<LanguageProvider>().t('home.recent_history'),
                  lang: lang),
            ),
            SliverToBoxAdapter(
              child: _RecentHistoriaStrip(
                history: rp.history.skip(1).toList(),
                lang: lang,
              ),
            ),
          ],

          // ── Progreso histórico ───────────────────────────────────────────
          if (rp.hasHistory) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                  label: context
                      .read<LanguageProvider>()
                      .t('home.historical_progress'),
                  lang: lang),
            ),
            SliverToBoxAdapter(
              child: _StageProgressSection(lang: lang),
            ),
          ],

          // ── Continuar explorando ─────────────────────────────────────────
          if (history.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                  label: context
                      .read<LanguageProvider>()
                      .t('home.continue_exploring'),
                  lang: lang),
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
              onTap: () => AppNavigation.openPremium(context),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
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
                      context.read<LanguageProvider>().t('home.hero_eyebrow'),
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
                  context.read<LanguageProvider>().t('home.hero_title'),
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
                  context.read<LanguageProvider>().t('home.hero_subtitle'),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    color: AppColors.cremaPergamino.withOpacity(0.7),
                  ),
                ).animate().fadeIn(duration: 800.ms, delay: 480.ms),
                const SizedBox(height: 30),
                // Buttons
                Row(
                  children: [
                    _HeroButton(
                      label: context
                          .read<LanguageProvider>()
                          .t('home.start_journey'),
                      isPrimary: true,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const WorldScreen(worldId: 'historia'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _HeroButton(
                      label: context
                          .read<LanguageProvider>()
                          .t('home.explore_eras'),
                      isPrimary: false,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const WorldScreen(worldId: 'historia'),
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
}

class _HeroButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _HeroButton(
      {required this.label, required this.isPrimary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ocre,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
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

// ── Peru intro section ────────────────────────────────────────────────────────

class _PeruIntroSection extends StatelessWidget {
  final String lang;
  const _PeruIntroSection({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats + Map card ──
          Container(
            decoration: BoxDecoration(
              color: AppColors.marronProfundo,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.ocre.withOpacity(0.15),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map drawing
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomPaint(
                      size: const Size(100, 130),
                      painter: _PeruMapPainter(),
                    ),
                  ),
                  // Stats column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PERÚ',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cremaPergamino,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Stat(
                            icon: Icons.location_city_rounded,
                            label: context
                                .read<LanguageProvider>()
                                .t('home.capital'),
                            value: 'Lima',
                          ),
                          const SizedBox(height: 8),
                          _Stat(
                            icon: Icons.map_rounded,
                            label:
                                context.read<LanguageProvider>().t('home.area'),
                            value: '1.285.216 km²',
                          ),
                          const SizedBox(height: 8),
                          _Stat(
                            icon: Icons.people_rounded,
                            label: context
                                .read<LanguageProvider>()
                                .t('home.population'),
                            value: '33 M',
                          ),
                          const SizedBox(height: 8),
                          _Stat(
                            icon: Icons.terrain_rounded,
                            label: context
                                .read<LanguageProvider>()
                                .t('home.regions'),
                            value: context
                                .read<LanguageProvider>()
                                .t('home.regions_value'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 100.ms)
              .slideY(begin: 0.08, end: 0),

          const SizedBox(height: 16),

          // ── Description card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.marronProfundo,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.ocre.withOpacity(0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 16, color: AppColors.ocre),
                    const SizedBox(width: 10),
                    Text(
                      context
                          .read<LanguageProvider>()
                          .t('home.about_title')
                          .toUpperCase(),
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ocre,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.read<LanguageProvider>().t('home.about_text'),
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    color: AppColors.cremaPergamino.withOpacity(0.75),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .slideY(begin: 0.08, end: 0),

          const SizedBox(height: 16),

          // ── How to use card ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.ocre.withOpacity(0.12),
                  AppColors.marronProfundo,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.ocre.withOpacity(0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.explore_rounded,
                        color: AppColors.ocre, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      context
                          .read<LanguageProvider>()
                          .t('home.how_title')
                          .toUpperCase(),
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ocre,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _HowStep(
                    number: '1',
                    text: context.read<LanguageProvider>().t('home.step_1')),
                const SizedBox(height: 10),
                _HowStep(
                    number: '2',
                    text: context.read<LanguageProvider>().t('home.step_2')),
                const SizedBox(height: 10),
                _HowStep(
                    number: '3',
                    text: context.read<LanguageProvider>().t('home.step_3')),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 300.ms)
              .slideY(begin: 0.08, end: 0),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: AppColors.ocre.withOpacity(0.7)),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: GoogleFonts.lato(
                    fontSize: 11,
                    color: AppColors.cremaPergamino.withOpacity(0.45),
                  ),
                ),
                TextSpan(
                  text: value,
                  style: GoogleFonts.lato(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cremaPergamino.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HowStep extends StatelessWidget {
  final String number;
  final String text;
  const _HowStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.ocre.withOpacity(0.2),
            border: Border.all(color: AppColors.ocre.withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.lato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.ocre,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.lato(
              fontSize: 13,
              color: AppColors.cremaPergamino.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _PeruMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ocre.withOpacity(0.55)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.ocre.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Silueta real del Perú. Los vértices se derivan de coordenadas
    // geográficas aproximadas (lon/lat) normalizadas a la caja del lienzo:
    //   x = (81.3 - lon) / 12.7   ·   y = lat_sur / 18.35
    // Recorrido en sentido horario partiendo del extremo norte (Putumayo).
    final w = size.width;
    final h = size.height;
    Offset p(double fx, double fy) => Offset(w * fx, h * fy);

    final path = Path()
      ..moveTo(w * 0.50, h * 0.01) // Extremo norte (Putumayo, Loreto)
      // ── Frontera oriental (Colombia / Brasil), trazo quebrado amazónico ──
      ..lineTo(w * 0.64, h * 0.05)
      ..lineTo(w * 0.83, h * 0.14)
      ..lineTo(w * 0.92, h * 0.30)
      ..lineTo(w * 1.00, h * 0.52) // Punto más oriental (Madre de Dios)
      ..lineTo(w * 0.97, h * 0.66)
      ..lineTo(w * 0.94, h * 0.86) // Zona del Lago Titicaca (frontera Bolivia)
      // ── Extremo sur ──
      ..lineTo(w * 0.86, h * 0.99) // Tacna (punto más austral)
      // ── Costa del Pacífico, ascendiendo (curva suave) ──
      ..lineTo(w * 0.76, h * 0.94) // Moquegua
      ..lineTo(w * 0.60, h * 0.87) // Arequipa / Camaná
      ..lineTo(w * 0.41, h * 0.76) // Península de Paracas (saliente)
      ..lineTo(w * 0.335, h * 0.66) // Lima / Callao
      ..lineTo(w * 0.21, h * 0.49) // Chimbote
      ..lineTo(w * 0.04, h * 0.34) // Sechura (saliente más occidental)
      ..lineTo(w * 0.02, h * 0.245) // Talara
      ..lineTo(w * 0.08, h * 0.185) // Tumbes (esquina noroeste)
      // ── Frontera norte (Ecuador), de vuelta al extremo norte ──
      ..lineTo(w * 0.22, h * 0.11)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // ── Lima (capital, sobre la costa central) ──
    final limaPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    final lima = p(0.335, 0.66);
    canvas.drawCircle(lima, 3.0, limaPaint);

    final tp = TextPainter(
      text: TextSpan(
        text: 'Lima',
        style: GoogleFonts.lato(
          fontSize: 8,
          color: Colors.white.withOpacity(0.85),
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, lima + Offset(w * 0.05, -h * 0.03));

    // ── Cusco (interior sur-andino) ──
    final cuscoPaint = Paint()
      ..color = AppColors.ocre.withOpacity(0.95)
      ..style = PaintingStyle.fill;
    final cusco = p(0.73, 0.74);
    canvas.drawCircle(cusco, 2.5, cuscoPaint);

    final tp2 = TextPainter(
      text: TextSpan(
        text: 'Cusco',
        style: GoogleFonts.lato(
          fontSize: 7,
          color: AppColors.ocre.withOpacity(0.85),
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Etiqueta a la izquierda del punto para no salir de la caja.
    tp2.paint(canvas, cusco + Offset(-tp2.width - w * 0.04, -h * 0.025));
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
            ).animate().fadeIn(duration: 500.ms, delay: (i * 80).ms).scale(
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
                  assetImagePath: era.imageAssetPath(era.imageFilenames.first),
                  accentColor: era.accentColor,
                  title: t('eras.${era.id}.title'),
                  subtitle: t('eras.${era.id}.period'),
                  badge:
                      context.read<LanguageProvider>().t('home.featured_badge'),
                  isPremium: isLocked,
                  height: 220,
                  // Caral carece de fotografía: fallback artístico a medida.
                  imageFallback: era.id == 'caral'
                      ? CaralPlaceholder(accentColor: era.accentColor)
                      : null,
                  onTap: () => AppNavigation.openEra(
                    context,
                    era,
                    isLocked: isLocked,
                  ),
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
        onTap: () => AppNavigation.openContent(context, item),
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
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DiagonalPatternPainter(const Color(0xFF8B4513)),
                  ),
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
                          color: const Color(0xFF8B4513).withOpacity(0.4),
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
                              context
                                  .read<LanguageProvider>()
                                  .t('home.character_of_day')
                                  .toUpperCase(),
                              style: GoogleFonts.lato(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ocre,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.localizedTitle(
                                  context.read<LanguageProvider>().t),
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
                                  context
                                      .read<LanguageProvider>()
                                      .t('home.view_biography'),
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
              accentColor: era?.accentColor ?? const Color(0xFF6B4226),
              title: item.localizedTitle(context.read<LanguageProvider>().t),
              width: 160,
              height: 130,
              onTap: () {
                if (era != null) {
                  AppNavigation.openEra(context, era);
                } else {
                  AppNavigation.openContent(context, item);
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

// ── Journey card (last article opened) ───────────────────────────────────────

class _JourneyCard extends StatefulWidget {
  final String articleId;
  final String stageId;
  final int progress;
  final String lang;

  const _JourneyCard({
    required this.articleId,
    required this.stageId,
    required this.progress,
    required this.lang,
  });

  @override
  State<_JourneyCard> createState() => _JourneyCardState();
}

class _JourneyCardState extends State<_JourneyCard> {
  late Future<(HistoriaArticle?, HistoriaStage?)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(widget.articleId, widget.stageId);
  }

  @override
  void didUpdateWidget(_JourneyCard old) {
    super.didUpdateWidget(old);
    if (old.articleId != widget.articleId || old.stageId != widget.stageId) {
      _future = _load(widget.articleId, widget.stageId);
    }
  }

  Future<(HistoriaArticle?, HistoriaStage?)> _load(
      String articleId, String stageId) async {
    final stages = await HistoriaStagesRepository.loadStages();
    final stage = stages.cast<HistoriaStage?>().firstWhere(
          (s) => s?.id == stageId,
          orElse: () => null,
        );
    if (stage == null) return (null, null);
    final articles =
        await HistoriaStagesRepository.loadArticlesForStage(stageId);
    final article = articles.cast<HistoriaArticle?>().firstWhere(
          (a) => a?.id == articleId,
          orElse: () => null,
        );
    return (article, stage);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(HistoriaArticle?, HistoriaStage?)>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 120);
        final (article, stage) = snap.data!;
        if (article == null) return const SizedBox.shrink();
        return _buildCard(context, article, stage);
      },
    );
  }

  Widget _buildCard(
      BuildContext context, HistoriaArticle article, HistoriaStage? stage) {
    final accent = stage?.accentColor ?? AppColors.ocre;
    final pct = widget.progress / 100.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () async {
          final allArticles = stage != null
              ? await HistoriaStagesRepository.loadArticlesForStage(stage.id)
              : <HistoriaArticle>[];
          if (!context.mounted) return;
          AppNavigation.openHistoriaArticle(
            context,
            article: article,
            allArticles: allArticles,
            stage: stage,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(accent, Colors.black, 0.6)!,
                AppColors.negoCacao,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 24, height: 1.5, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        (stage?.tituloFor(widget.lang) ?? '').toUpperCase(),
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article.tituloFor(widget.lang),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cremaPergamino,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.subtituloFor(widget.lang),
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: AppColors.cremaPergamino.withOpacity(0.55),
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (ctx, c) => Stack(
                            children: [
                              Container(
                                height: 3,
                                width: c.maxWidth,
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOut,
                                height: 3,
                                width: c.maxWidth * pct,
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${widget.progress}%',
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        context
                            .read<LanguageProvider>()
                            .t('home.continue_reading'),
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: accent),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.08, end: 0),
      ),
    );
  }
}

// ── Recent Historia strip ─────────────────────────────────────────────────────

class _RecentHistoriaStrip extends StatefulWidget {
  final List<ArticleHistoryEntry> history;
  final String lang;

  const _RecentHistoriaStrip({required this.history, required this.lang});

  @override
  State<_RecentHistoriaStrip> createState() => _RecentHistoriaStripState();
}

class _RecentHistoriaStripState extends State<_RecentHistoriaStrip> {
  late Future<List<(HistoriaArticle, HistoriaStage?)>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(widget.history);
  }

  @override
  void didUpdateWidget(_RecentHistoriaStrip old) {
    super.didUpdateWidget(old);
    if (old.history != widget.history) {
      _future = _load(widget.history);
    }
  }

  Future<List<(HistoriaArticle, HistoriaStage?)>> _load(
      List<ArticleHistoryEntry> entries) async {
    final stages = await HistoriaStagesRepository.loadStages();
    final results = <(HistoriaArticle, HistoriaStage?)>[];
    for (final entry in entries.take(6)) {
      final stage = stages.cast<HistoriaStage?>().firstWhere(
            (s) => s?.id == entry.stageId,
            orElse: () => null,
          );
      final articles =
          await HistoriaStagesRepository.loadArticlesForStage(entry.stageId);
      final article = articles.cast<HistoriaArticle?>().firstWhere(
            (a) => a?.id == entry.articleId,
            orElse: () => null,
          );
      if (article != null) results.add((article, stage));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReadingProgressProvider>();
    return FutureBuilder<List<(HistoriaArticle, HistoriaStage?)>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return const SizedBox(height: 120);
        }
        final items = snap.data!;
        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final (article, stage) = items[i];
              final accent = stage?.accentColor ?? AppColors.ocre;
              final pct = rp.progressFor(article.id) / 100.0;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () async {
                    final allArticles = stage != null
                        ? await HistoriaStagesRepository.loadArticlesForStage(
                            stage.id)
                        : <HistoriaArticle>[];
                    if (!context.mounted) return;
                    AppNavigation.openHistoriaArticle(
                      context,
                      article: article,
                      allArticles: allArticles,
                      stage: stage,
                    );
                  },
                  child: Container(
                    width: 160,
                    decoration: BoxDecoration(
                      color: AppColors.marronProfundo,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withOpacity(0.2)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.tituloFor(widget.lang),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cremaPergamino,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        LayoutBuilder(
                          builder: (ctx, c) => Stack(
                            children: [
                              Container(
                                height: 2,
                                width: c.maxWidth,
                                color: accent.withOpacity(0.15),
                              ),
                              Container(
                                height: 2,
                                width: c.maxWidth * pct,
                                color: accent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${rp.progressFor(article.id)}%',
                          style: GoogleFonts.lato(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accent.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: (i * 60).ms)
                      .slideX(begin: 0.1, end: 0),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Stage progress section ────────────────────────────────────────────────────

class _StageProgressSection extends StatefulWidget {
  final String lang;
  const _StageProgressSection({required this.lang});

  @override
  State<_StageProgressSection> createState() => _StageProgressSectionState();
}

class _StageProgressSectionState extends State<_StageProgressSection> {
  late Future<List<(HistoriaStage, List<HistoriaArticle>)>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<(HistoriaStage, List<HistoriaArticle>)>> _load() async {
    final stages = await HistoriaStagesRepository.loadStages();
    final results = <(HistoriaStage, List<HistoriaArticle>)>[];
    for (final stage in stages) {
      final articles =
          await HistoriaStagesRepository.loadArticlesForStage(stage.id);
      if (articles.isNotEmpty) results.add((stage, articles));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<ReadingProgressProvider>();
    return FutureBuilder<List<(HistoriaStage, List<HistoriaArticle>)>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 80);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.marronProfundo,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.ocre.withOpacity(0.12)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: snap.data!.map((entry) {
                final (stage, articles) = entry;
                final done = articles.where((a) => rp.isCompleted(a.id)).length;
                return _StageProgressRow(
                  stage: stage,
                  done: done,
                  total: articles.length,
                  lang: widget.lang,
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _StageProgressRow extends StatelessWidget {
  final HistoriaStage stage;
  final int done;
  final int total;
  final String lang;

  const _StageProgressRow({
    required this.stage,
    required this.done,
    required this.total,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? done / total : 0.0;
    final accent = stage.accentColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stage.tituloFor(lang),
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cremaPergamino,
                  ),
                ),
              ),
              Text(
                '$done / $total',
                style: GoogleFonts.lato(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (ctx, c) => Stack(
              children: [
                Container(
                  height: 4,
                  width: c.maxWidth,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: fraction),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  builder: (ctx, val, _) => Container(
                    height: 4,
                    width: c.maxWidth * val,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
