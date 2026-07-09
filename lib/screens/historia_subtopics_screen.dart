import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigation.dart';
import '../data/historia_stages_repository.dart';
import '../models/historia_article.dart';
import '../models/historia_stage.dart';
import '../providers/language_provider.dart';
import '../widgets/app_state_views.dart';

class HistoriaSubtopicsScreen extends StatefulWidget {
  final HistoriaStage stage;
  final List<String> carouselImages;

  const HistoriaSubtopicsScreen({
    super.key,
    required this.stage,
    this.carouselImages = const [],
  });

  @override
  State<HistoriaSubtopicsScreen> createState() =>
      _HistoriaSubtopicsScreenState();
}

class _HistoriaSubtopicsScreenState extends State<HistoriaSubtopicsScreen> {
  late final PageController _pageCtrl;
  Timer? _timer;
  int _currentPage = 0;

  bool get _hasCarousel => widget.carouselImages.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _startAutoPlay();
  }

  /// Inicia (o reinicia) el auto-avance. No avanza mientras el usuario
  /// está deslizando manualmente.
  void _startAutoPlay() {
    _timer?.cancel();
    if (widget.carouselImages.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      final next = (_currentPage + 1) % widget.carouselImages.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
      );
    });
  }

  /// Va a la página indicada (con límites) y reinicia el auto-avance.
  void _goToPage(int page) {
    final n = widget.carouselImages.length;
    if (n <= 1 || !_pageCtrl.hasClients) return;
    final target = page.clamp(0, n - 1);
    if (target == _currentPage) return;
    _pageCtrl.animateToPage(
      target,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOut,
    );
    _startAutoPlay(); // reinicia la cuenta tras interacción manual
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final accent = widget.stage.accentColor;
    final screenHeight = MediaQuery.of(context).size.height;
    final carouselHeight = screenHeight * 0.40;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      // El carrusel va como contenido normal del scroll (no dentro de un
      // FlexibleSpaceBar) para que el PageView reciba los gestos horizontales.
      // El botón de volver se superpone con un Stack.
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: carouselHeight,
                  child: _hasCarousel
                      ? _buildCarousel(accent, lang)
                      : _buildGradientFallback(accent, lang),
                ),
              ),
              SliverToBoxAdapter(
                child: FutureBuilder<List<HistoriaArticle>>(
                  future: HistoriaStagesRepository.loadArticlesForStage(
                      widget.stage.id),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return AppLoadingState(
                        height: 300,
                        color: widget.stage.accentColor,
                      );
                    }
                    if (!snap.hasData || snap.data!.isEmpty) {
                      return const AppErrorState(height: 300);
                    }
                    return _SubtopicsBody(
                      articles: snap.data!,
                      stage: widget.stage,
                      lang: lang,
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
          // Botón volver superpuesto
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 10,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.42),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Carousel con imágenes ─────────────────────────────────────────────────

  Widget _buildCarousel(Color accent, String lang) {
    final dark = Color.lerp(accent, Colors.black, 0.5)!;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imágenes. La física es manejada por el GestureDetector superior
          // (NeverScrollable evita conflictos con el overlay encima).
          PageView.builder(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.carouselImages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, i) {
              return Image.asset(
                widget.carouselImages[i],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, dark],
                    ),
                  ),
                ),
              );
            },
          ),

          // Overlay cinematográfico
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x3D000000), // 24%
                  Color(0xB3000000), // 70%
                ],
              ),
            ),
          ),

          // Contenido superpuesto (periodo + título + subtítulo)
          Positioned(
            bottom: 44,
            left: 22,
            right: 22,
            child: _buildHeaderContent(accent, lang),
          ),

          // Dot indicators
          if (widget.carouselImages.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.carouselImages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentPage == i ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? Colors.white
                          : Colors.white.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),

          // Capa de gestos (encima de todo): captura el deslizamiento
          // horizontal del dedo y controla el carrusel. Los gestos verticales
          // pasan al scroll de la página (translucent).
          if (widget.carouselImages.length > 1)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v < -80) {
                    _goToPage(_currentPage + 1); // desliza a la izquierda → siguiente
                  } else if (v > 80) {
                    _goToPage(_currentPage - 1); // desliza a la derecha → anterior
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── Fallback gradiente (sin imágenes) ────────────────────────────────────

  Widget _buildGradientFallback(Color accent, String lang) {
    final dark = Color.lerp(accent, Colors.black, 0.5)!;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, dark],
              ),
            ),
          ),
          CustomPaint(painter: _DiagPainter(accent)),
          Positioned(
            right: -20,
            top: 10,
            child: Icon(
              Icons.history_edu_rounded,
              size: 200,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 22,
            right: 22,
            child: _buildHeaderContent(accent, lang),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderContent(Color accent, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Period badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
          ),
          child: Text(
            widget.stage.periodoFor(lang),
            style: GoogleFonts.lato(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.stage.tituloFor(lang),
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.stage.subtituloFor(lang),
          style: GoogleFonts.lato(
            fontSize: 12,
            color: Colors.white.withOpacity(0.72),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

// ── Lista de subtemas ─────────────────────────────────────────────────────────

class _SubtopicsBody extends StatelessWidget {
  final List<HistoriaArticle> articles;
  final HistoriaStage stage;
  final String lang;

  const _SubtopicsBody({
    required this.articles,
    required this.stage,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final accent = stage.accentColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Row(
            children: [
              Container(width: 3, height: 16, color: accent),
              const SizedBox(width: 10),
              Text(
                context
                    .read<LanguageProvider>()
                    .t('historia.articles')
                    .toUpperCase(),
                style: GoogleFonts.lato(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cremaPergamino,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(articles.length, (i) {
            return _SubtopicCard(
              article: articles[i],
              allArticles: articles,
              stage: stage,
              lang: lang,
              index: i,
            );
          }),
        ],
      ),
    );
  }
}

class _SubtopicCard extends StatelessWidget {
  final HistoriaArticle article;
  final List<HistoriaArticle> allArticles;
  final HistoriaStage stage;
  final String lang;
  final int index;

  const _SubtopicCard({
    required this.article,
    required this.allArticles,
    required this.stage,
    required this.lang,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final accent = stage.accentColor;
    final preview = _previewText();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.marronProfundo,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => AppNavigation.openHistoriaArticle(
            context,
            article: article,
            allArticles: allArticles,
            stage: stage,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(0.15)),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Orden badge
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Text(
                      '${article.orden}',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (article.periodoFor(lang) != null) ...[
                        Text(
                          article.periodoFor(lang)!,
                          style: GoogleFonts.lato(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: accent.withOpacity(0.75),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        article.tituloFor(lang),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cremaPergamino,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        article.subtituloFor(lang),
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.cremaPergamino.withOpacity(0.5),
                          height: 1.3,
                        ),
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          preview,
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            color: AppColors.cremaPergamino.withOpacity(0.55),
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 9, color: accent),
                          const SizedBox(width: 5),
                          Text(
                            context
                                .read<LanguageProvider>()
                                .t('historia.read_article'),
                            style: GoogleFonts.lato(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 450.ms, delay: (index * 70).ms)
        .slideY(begin: 0.05, end: 0, duration: 450.ms, delay: (index * 70).ms);
  }

  String _previewText() {
    final content = article.contenidoFor(lang);
    final paragraphs =
        content.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    if (paragraphs.isEmpty) return '';
    final first = paragraphs.first.trim();
    return first.length > 110 ? '${first.substring(0, 110)}…' : first;
  }
}

class _DiagPainter extends CustomPainter {
  final Color color;
  const _DiagPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = 1;
    const spacing = 28.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
