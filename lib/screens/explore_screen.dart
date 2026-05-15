import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/category_config.dart';
import '../data/content_repository.dart';
import '../data/eras_repository.dart';
import '../data/historia_stages_repository.dart';
import '../models/content_item.dart';
import '../models/era_model.dart';
import '../models/historia_stage.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/cinematic_card.dart';
import '../widgets/historia_timeline.dart';
import '../widgets/wiki_cinematic_card.dart';
import 'content_detail_screen.dart';
import 'era_detail_screen.dart';
import 'historia_subtopics_screen.dart';
import 'premium_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _activeFilter = 'era';

  static const _filters = [
    'era', 'personaje', 'tradicion', 'gastronomia', 'musica', 'geografia'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Returns true when we show the editorial stages view
  bool get _showStages => _activeFilter == 'era' && _query.isEmpty;

  List<ContentItem> _filtered(String lang) {
    final allErasAsItems = ErasRepository.allEras.map((e) => ContentItem(
          id: e.id,
          category: 'era',
          wikipediaSlug: e.wikipediaSlug,
          isPremium: e.isPremium,
        ));
    final all = [
      ...allErasAsItems,
      ...ContentRepository.personajes,
      ...ContentRepository.tradiciones,
      ...ContentRepository.gastronomia,
      ...ContentRepository.musica,
      ...ContentRepository.geografia,
    ];

    var result = all;
    if (_activeFilter != 'all') {
      result = result.where((i) => i.category == _activeFilter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result
          .where((i) => i.displayName.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final isPremium = context.watch<PremiumProvider>().isPremium;
    final items = _showStages ? <ContentItem>[] : _filtered(lang);

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(lang).toUpperCase(),
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ocre,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(lang),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cremaPergamino,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.marronProfundo,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.cremaPergamino.withOpacity(0.1),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      style: GoogleFonts.lato(
                        color: AppColors.cremaPergamino,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: _hint(lang),
                        hintStyle: GoogleFonts.lato(
                          color: AppColors.cremaPergamino.withOpacity(0.3),
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppColors.cremaPergamino.withOpacity(0.4),
                        ),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded,
                                    color: AppColors.cremaPergamino
                                        .withOpacity(0.4)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Filter chips ─────────────────────────────────────────────
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                itemBuilder: (context, i) {
                  final f = _filters[i];
                  final isActive = _activeFilter == f;
                  final color = f == 'all'
                      ? AppColors.ocre
                      : CategoryConfigs.colorOf(f);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _activeFilter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive
                              ? color.withOpacity(0.2)
                              : AppColors.marronProfundo,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? color.withOpacity(0.7)
                                : AppColors.cremaPergamino.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _filterLabel(f, lang),
                          style: GoogleFonts.lato(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? color
                                : AppColors.cremaPergamino.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // ── Results count ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    _showStages
                        ? '4 ${_stagesCountLabel(lang)}'
                        : '${items.length} ${_resultsLabel(lang)}',
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: AppColors.cremaPergamino.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Content area ─────────────────────────────────────────────
            if (_showStages)
              Expanded(child: _HistoriaStagesView(lang: lang))
            else
              Expanded(
                child: items.isEmpty
                    ? _buildEmptyState(lang)
                    : _buildGrid(context, lang, items, isPremium),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, String lang, List<ContentItem> items,
      bool isPremium) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final era = item.category == 'era'
            ? ErasRepository.allEras
                .cast<EraModel?>()
                .firstWhere((e) => e?.id == item.id, orElse: () => null)
            : null;
        final isLocked = item.isPremium && !isPremium;
        final t = context.read<LanguageProvider>().t;
        final tapAction = isLocked
            ? () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()))
            : era != null
                ? () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => EraDetailScreen(era: era)))
                : () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => ContentDetailScreen(item: item)));

        if (era != null) {
          return CinematicCard(
            assetImagePath: era.imageAssetPath(era.imageFilenames.first),
            accentColor: era.accentColor,
            title: t('eras.${era.id}.title'),
            subtitle: t('eras.${era.id}.period'),
            isPremium: isLocked,
            onTap: tapAction,
          ).animate().fadeIn(
              duration: 400.ms, delay: Duration(milliseconds: i * 40));
        }

        return WikiCinematicCard(
          item: item,
          subtitle: CategoryConfigs.labelOf(item.category, lang),
          isPremium: isLocked,
          onTap: tapAction,
        )
            .animate()
            .fadeIn(
              duration: 400.ms,
              delay: Duration(milliseconds: i * 40),
            );
      },
    );
  }

  Widget _buildEmptyState(String lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 56,
              color: AppColors.cremaPergamino.withOpacity(0.15)),
          const SizedBox(height: 16),
          Text(
            _noResults(lang),
            style: GoogleFonts.lato(
              fontSize: 15,
              color: AppColors.cremaPergamino.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(String filter, String lang) =>
      CategoryConfigs.labelOf(filter, lang);

  String _title(String lang) => switch (lang) {
        'en' => 'Explore',
        'es' => 'Explorar',
        _ => 'Esplora',
      };
  String _subtitle(String lang) => switch (lang) {
        'en' => 'Discover Peru',
        'es' => 'Descubre el Perú',
        _ => 'Scopri il Perù',
      };
  String _hint(String lang) => switch (lang) {
        'en' => 'Search history, people, food...',
        'es' => 'Buscar historia, personas, comida...',
        _ => 'Cerca storia, persone, cibo...',
      };
  String _resultsLabel(String lang) => switch (lang) {
        'en' => 'results',
        'es' => 'resultados',
        _ => 'risultati',
      };
  String _stagesCountLabel(String lang) => switch (lang) {
        'en' => 'historical stages',
        'es' => 'etapas históricas',
        _ => 'fasi storiche',
      };
  String _noResults(String lang) => switch (lang) {
        'en' => 'No results found',
        'es' => 'Sin resultados',
        _ => 'Nessun risultato',
      };
}

// ── Vista de etapas históricas ────────────────────────────────────────────────

class _HistoriaStagesView extends StatelessWidget {
  final String lang;
  const _HistoriaStagesView({required this.lang});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HistoriaStage>>(
      future: HistoriaStagesRepository.loadStages(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.worldHistoria),
          );
        }
        final stages = snap.data ?? [];
        if (stages.isEmpty) {
          return const Center(
            child: Icon(Icons.error_outline, color: Colors.white38, size: 48),
          );
        }

        final stageMap = {for (final s in stages) s.id: s};

        return CustomScrollView(
          slivers: [
            // ── Interactive timeline ──────────────────────────────────
            SliverToBoxAdapter(
              child: HistoriaTimeline(
                lang: lang,
                onItemTap: (item) {
                  final stage = stageMap[item.stageId];
                  if (stage == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoriaSubtopicsScreen(
                        stage: stage,
                        carouselImages:
                            HistoriaStagesRepository.carouselImagesForStage(
                                stage.id),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Section divider ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(width: 3, height: 16, color: AppColors.worldHistoria),
                    const SizedBox(width: 10),
                    Text(
                      _stagesLabel(lang).toUpperCase(),
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
            ),

            // ── Stage cards ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _StageCard(stage: stages[i], lang: lang, index: i),
                  ),
                  childCount: stages.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _stagesLabel(String lang) => switch (lang) {
        'en' => 'Historical Stages',
        'es' => 'Etapas Históricas',
        _ => 'Fasi Storiche',
      };
}

class _StageCard extends StatelessWidget {
  final HistoriaStage stage;
  final String lang;
  final int index;

  const _StageCard({
    required this.stage,
    required this.lang,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final accent = stage.accentColor;
    final dark = Color.lerp(accent, Colors.black, 0.5)!;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HistoriaSubtopicsScreen(
                stage: stage,
                carouselImages:
                    HistoriaStagesRepository.carouselImagesForStage(stage.id),
              ),
        ),
      ),
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, dark],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Diagonal pattern
              CustomPaint(painter: _DiagPainter(accent)),
              // Watermark icon
              Positioned(
                right: -20,
                top: -10,
                child: Icon(
                  Icons.history_edu_rounded,
                  size: 180,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              // Stage number
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      '${stage.orden}',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
              ),
              // Content
              Positioned(
                bottom: 20,
                left: 20,
                right: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Period badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: Text(
                        stage.periodoFor(lang),
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.85),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stage.tituloFor(lang),
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage.subtituloFor(lang),
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Arrow
              Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (index * 80).ms)
        .slideY(begin: 0.04, end: 0, duration: 400.ms, delay: (index * 80).ms);
  }
}

class _DiagPainter extends CustomPainter {
  final Color color;
  const _DiagPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
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
