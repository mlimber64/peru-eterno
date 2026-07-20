import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/historia_article.dart';
import '../models/historia_stage.dart';
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../providers/reading_progress_provider.dart';
import '../providers/reading_text_scale_provider.dart';
import '../widgets/historia_rich_text.dart';

class HistoriaArticleDetailScreen extends StatefulWidget {
  final HistoriaArticle article;
  final List<HistoriaArticle> allArticles;
  final HistoriaStage? stage;
  final List<String> carouselImages;

  const HistoriaArticleDetailScreen({
    super.key,
    required this.article,
    required this.allArticles,
    this.stage,
    this.carouselImages = const [],
  });

  @override
  State<HistoriaArticleDetailScreen> createState() =>
      _HistoriaArticleDetailScreenState();
}

class _HistoriaArticleDetailScreenState
    extends State<HistoriaArticleDetailScreen> {
  late final PageController _pageCtrl;
  late final ScrollController _scrollCtrl;
  Timer? _timer;
  int _currentPage = 0;
  int _lastSavedProgress = 0;

  // ── Pellizco de dos dedos para escalar el texto ──────────────────────────
  final Map<int, Offset> _pointers = {};
  double? _baseDistance; // distancia entre dedos al iniciar el pellizco
  double _baseScale = 1.0; // escala al iniciar el pellizco
  bool _pinching = false;

  Color get _accent => widget.stage?.accentColor ?? AppColors.worldHistoria;
  bool get _hasCarousel => widget.carouselImages.isNotEmpty;
  String get _stageId {
    final stageId = widget.stage?.id ?? widget.article.parentStageId;
    if (stageId != null && stageId.isNotEmpty && stageId != 'unknown') {
      return stageId;
    }
    return 'peru_prehispanico';
  }

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _scrollCtrl = ScrollController();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReadingProgressProvider>().openArticle(
            widget.article.id,
            _stageId,
          );
    });
    if (widget.carouselImages.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 7), (_) {
        if (!mounted) return;
        final next = (_currentPage + 1) % widget.carouselImages.length;
        _pageCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _pageCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    if (!pos.hasContentDimensions || pos.maxScrollExtent == 0) return;
    final pct = (pos.pixels / pos.maxScrollExtent * 100).round().clamp(0, 100);
    if ((pct - _lastSavedProgress).abs() >= 5) {
      _lastSavedProgress = pct;
      if (mounted) {
        context
            .read<ReadingProgressProvider>()
            .updateProgress(widget.article.id, pct);
      }
    }
  }

  // ── Manejo del pellizco con Listener (no compite con el scroll) ──────────
  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      final pts = _pointers.values.toList();
      _baseDistance = (pts[0] - pts[1]).distance;
      _baseScale = context.read<ReadingTextScaleProvider>().scale;
      setState(() => _pinching = true);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    if (_pointers.length >= 2 && _baseDistance != null && _baseDistance! > 0) {
      final pts = _pointers.values.toList();
      final dist = (pts[0] - pts[1]).distance;
      final factor = dist / _baseDistance!;
      context.read<ReadingTextScaleProvider>().setScale(_baseScale * factor);
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2 && _pinching) {
      _baseDistance = null;
      setState(() => _pinching = false);
      context.read<ReadingTextScaleProvider>().persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final textScale = context.watch<ReadingTextScaleProvider>().scale;
    final isFav =
        context.watch<FavoritesProvider>().isFavorite(widget.article.id);
    final readingPct = context
            .watch<ReadingProgressProvider>()
            .progressFor(widget.article.id) /
        100.0;

    final screenHeight = MediaQuery.of(context).size.height;
    final carouselHeight = screenHeight * 0.38;

    final paragraphs = widget.article
        .contenidoFor(lang)
        .split('\n\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    final idx = widget.allArticles.indexWhere((a) => a.id == widget.article.id);
    final hasPrev = idx > 0;
    final hasNext = idx < widget.allArticles.length - 1;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
          // ── Hero Carousel ────────────────────────────────────────────────
          _buildSliverAppBar(context, isFav, carouselHeight, readingPct),

          // ── Título y subtítulo ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildTitleSection(lang),
          ),

          // ── Chips informativos ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildChips(lang),
          ),

          // ── Cuerpo del artículo ──────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i.isOdd) {
                    // Separador entre párrafos. Se omite el divisor cuando
                    // alguno de los párrafos adyacentes es un callout
                    // ("¿Sabías qué?"), que ya trae su propio recuadro.
                    final before = paragraphs[(i - 1) ~/ 2];
                    final after = paragraphs[(i + 1) ~/ 2];
                    if (HistoriaParagraph.isCallout(before) ||
                        HistoriaParagraph.isCallout(after)) {
                      return const SizedBox(height: 20);
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Divider(
                        color: _accent.withOpacity(0.12),
                        thickness: 1,
                      ),
                    );
                  }
                  final pIndex = i ~/ 2;
                  return HistoriaParagraph(
                    text: paragraphs[pIndex].trim(),
                    accent: _accent,
                    textScale: textScale,
                  ).animate().fadeIn(duration: 500.ms, delay: (pIndex * 90).ms);
                },
                childCount: paragraphs.isEmpty ? 0 : paragraphs.length * 2 - 1,
              ),
            ),
          ),

          // ── Fuentes ──────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildSourcesSection(lang)),

          // ── Esplora anche ────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildRelatedSection(context, lang)),

          // ── Navegación prev / next ───────────────────────────────────────
          if (hasPrev || hasNext)
            SliverToBoxAdapter(
              child: _buildNavigation(context, lang, hasPrev, hasNext, idx),
            ),

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            ),
            // Indicador del tamaño de texto durante el pellizco
            if (_pinching)
              Center(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${(textScale * 100).round()}%',
                      style: GoogleFonts.lato(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── SliverAppBar con hero carousel ──────────────────────────────────────────

  SliverAppBar _buildSliverAppBar(BuildContext context, bool isFav,
      double carouselHeight, double readingPct) {
    final accent = _accent;

    return SliverAppBar(
      expandedHeight: carouselHeight,
      pinned: true,
      backgroundColor: AppColors.negoCacao,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: LayoutBuilder(
          builder: (context, constraints) => Container(
            height: 2,
            color: AppColors.negoCacao,
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              width: constraints.maxWidth * readingPct,
              height: 2,
              color: accent,
            ),
          ),
        ),
      ),
      leading: _floatingIconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 16, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        _floatingIconButton(
          icon: Icon(
            isFav ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
            size: 18,
            color: isFav ? accent : Colors.white,
          ),
          onPressed: () =>
              context.read<FavoritesProvider>().toggle(widget.article.id),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _hasCarousel
            ? _buildCarousel(accent)
            : _buildGradientFallback(accent),
      ),
    );
  }

  Widget _floatingIconButton(
      {required Widget icon, required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.all(10),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.42),
          shape: BoxShape.circle,
        ),
        child: Center(child: icon),
      ),
    );
  }

  // ── Carousel ─────────────────────────────────────────────────────────────────

  Widget _buildCarousel(Color accent) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Images
          PageView.builder(
            controller: _pageCtrl,
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
                      colors: [accent, Color.lerp(accent, Colors.black, 0.45)!],
                    ),
                  ),
                ),
              );
            },
          ),

          // Cinematic overlay — gradient dark top→bottom
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x3D000000), // 24%
                  Color(0x9E000000), // 62%
                ],
              ),
            ),
          ),

          // Left vignette
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0x26000000), Colors.transparent],
              ),
            ),
          ),

          // Dot indicators
          if (widget.carouselImages.length > 1)
            Positioned(
              bottom: 18,
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
        ],
      ),
    );
  }

  // ── Gradient fallback (cuando no hay imágenes) ────────────────────────────────

  Widget _buildGradientFallback(Color accent) {
    final dark = Color.lerp(accent, Colors.black, 0.45)!;
    return Stack(
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
          right: -30,
          top: 10,
          child: Icon(
            Icons.history_edu_rounded,
            size: 220,
            color: Colors.white.withOpacity(0.04),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, AppColors.negoCacao],
              stops: const [0.42, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  // ── Título y subtítulo ────────────────────────────────────────────────────────

  Widget _buildTitleSection(String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Orden badge + categoría
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: _accent.withOpacity(0.55), width: 1),
                ),
                child: Center(
                  child: Text(
                    '${widget.article.orden}',
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.article.categoriaFor(lang).toUpperCase(),
                  style: GoogleFonts.lato(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _accent.withOpacity(0.85),
                    letterSpacing: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.article.tituloFor(lang),
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.cremaPergamino,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.article.subtituloFor(lang),
            style: GoogleFonts.playfairDisplay(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.cremaPergamino.withOpacity(0.6),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ── Chips ─────────────────────────────────────────────────────────────────────

  Widget _buildChips(String lang) {
    final chips = <String>[];
    if (widget.stage != null) chips.add(widget.stage!.tituloFor(lang));
    final periodo = widget.article.periodoFor(lang);
    if (periodo != null && periodo.isNotEmpty) chips.add(periodo);
    if (chips.isEmpty) return const SizedBox(height: 16);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: chips.map((label) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withOpacity(0.3), width: 1),
            ),
            child: Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _accent,
                letterSpacing: 0.3,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Fuentes ───────────────────────────────────────────────────────────────────

  Widget _buildSourcesSection(String lang) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.marronProfundo,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accent.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: _accent.withOpacity(0.7)),
                const SizedBox(width: 8),
                Text(
                  context
                      .read<LanguageProvider>()
                      .t('historia.sources_title')
                      .toUpperCase(),
                  style: GoogleFonts.lato(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _accent.withOpacity(0.7),
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context.read<LanguageProvider>().t('historia.sources_body'),
              style: GoogleFonts.lato(
                fontSize: 12,
                color: AppColors.cremaPergamino.withOpacity(0.5),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Navegación prev / next ────────────────────────────────────────────────────

  Widget _buildNavigation(
    BuildContext context,
    String lang,
    bool hasPrev,
    bool hasNext,
    int idx,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.marronProfundo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.ocre.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            if (hasPrev)
              Expanded(
                child: _NavButton(
                  label:
                      context.read<LanguageProvider>().t('navigation.previous'),
                  subtitle: widget.allArticles[idx - 1].tituloFor(lang),
                  icon: Icons.arrow_back_ios_rounded,
                  isForward: false,
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoriaArticleDetailScreen(
                        article: widget.allArticles[idx - 1],
                        allArticles: widget.allArticles,
                        stage: widget.stage,
                        carouselImages: widget.carouselImages,
                      ),
                    ),
                  ),
                ),
              ),
            if (hasPrev && hasNext)
              Container(
                width: 1,
                height: 48,
                color: AppColors.ocre.withOpacity(0.12),
              ),
            if (hasNext)
              Expanded(
                child: _NavButton(
                  label: context.read<LanguageProvider>().t('navigation.next'),
                  subtitle: widget.allArticles[idx + 1].tituloFor(lang),
                  icon: Icons.arrow_forward_ios_rounded,
                  isForward: true,
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoriaArticleDetailScreen(
                        article: widget.allArticles[idx + 1],
                        allArticles: widget.allArticles,
                        stage: widget.stage,
                        carouselImages: widget.carouselImages,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Artículos relacionados ────────────────────────────────────────────────────

  Widget _buildRelatedSection(BuildContext context, String lang) {
    final others = widget.allArticles
        .where((a) => a.id != widget.article.id)
        .take(3)
        .toList();
    if (others.isEmpty) return const SizedBox.shrink();

    final accent = _accent;
    final dark = Color.lerp(accent, Colors.black, 0.55)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
          child: Row(
            children: [
              Container(width: 3, height: 16, color: accent),
              const SizedBox(width: 10),
              Text(
                context
                    .read<LanguageProvider>()
                    .t('historia.explore_also')
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
        ),
        SizedBox(
          height: 122,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: others.length,
            itemBuilder: (ctx, i) {
              final related = others[i];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => HistoriaArticleDetailScreen(
                        article: related,
                        allArticles: widget.allArticles,
                        stage: widget.stage,
                      ),
                    ),
                  ),
                  child: Container(
                    width: 158,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, dark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.25),
                          ),
                          child: Center(
                            child: Text(
                              '${related.orden}',
                              style: GoogleFonts.lato(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            related.tituloFor(lang),
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 8, color: Colors.white.withOpacity(0.7)),
                            const SizedBox(width: 4),
                            Text(
                              context
                                  .read<LanguageProvider>()
                                  .t('historia.read'),
                              style: GoogleFonts.lato(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: (i * 80).ms),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Botón de navegación ───────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool isForward;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.isForward,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              isForward ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  isForward ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isForward)
                  Icon(icon, size: 12, color: AppColors.ocre.withOpacity(0.6)),
                if (!isForward) const SizedBox(width: 4),
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.lato(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ocre.withOpacity(0.6),
                    letterSpacing: 1.2,
                  ),
                ),
                if (isForward) const SizedBox(width: 4),
                if (isForward)
                  Icon(icon, size: 12, color: AppColors.ocre.withOpacity(0.6)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.cremaPergamino.withOpacity(0.7),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: isForward ? TextAlign.end : TextAlign.start,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Diagonal pattern painter ──────────────────────────────────────────────────

class _DiagPainter extends CustomPainter {
  final Color color;
  const _DiagPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.07)
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
