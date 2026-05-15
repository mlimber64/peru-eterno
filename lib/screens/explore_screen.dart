import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/category_config.dart';
import '../data/content_repository.dart';
import '../data/eras_repository.dart';
import '../models/content_item.dart';
import '../models/era_model.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/cinematic_card.dart';
import '../widgets/wiki_cinematic_card.dart';
import 'content_detail_screen.dart';
import 'era_detail_screen.dart';
import 'premium_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _activeFilter = 'all';

  static const _filters = [
    'all', 'era', 'personaje', 'tradicion', 'gastronomia', 'musica', 'geografia'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
    final items = _filtered(lang);

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
                    '${items.length} ${_resultsLabel(lang)}',
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: AppColors.cremaPergamino.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Grid ─────────────────────────────────────────────────────
            Expanded(
              child: items.isEmpty
                  ? _buildEmptyState(lang)
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                                .firstWhere((e) => e?.id == item.id,
                                    orElse: () => null)
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
                                    MaterialPageRoute(builder: (_) => ContentDetailScreen(item: item)));

                        if (era != null) {
                          return CinematicCard(
                            assetImagePath: era.imageAssetPath(era.imageFilenames.first),
                            accentColor: era.accentColor,
                            title: t('eras.${era.id}.title'),
                            subtitle: t('eras.${era.id}.period'),
                            isPremium: isLocked,
                            onTap: tapAction,
                          ).animate().fadeIn(duration: 400.ms, delay: Duration(milliseconds: i * 40));
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
                    ),
            ),
          ],
        ),
      ),
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

  String _filterLabel(String filter, String lang) {
    if (filter == 'all') {
      return switch (lang) {
        'en' => 'All',
        'it' => 'Tutto',
        _ => 'Todo',
      };
    }
    return CategoryConfigs.labelOf(filter, lang);
  }

  String _title(String lang) => switch (lang) {
        'en' => 'Explore',
        'it' => 'Esplora',
        _ => 'Explorar',
      };
  String _subtitle(String lang) => switch (lang) {
        'en' => 'Discover Peru',
        'it' => 'Scopri il Perù',
        _ => 'Descubre el Perú',
      };
  String _hint(String lang) => switch (lang) {
        'en' => 'Search history, people, food...',
        'it' => 'Cerca storia, persone, cibo...',
        _ => 'Buscar historia, personas, comida...',
      };
  String _resultsLabel(String lang) => switch (lang) {
        'en' => 'results',
        'it' => 'risultati',
        _ => 'resultados',
      };
  String _noResults(String lang) => switch (lang) {
        'en' => 'No results found',
        'it' => 'Nessun risultato',
        _ => 'Sin resultados',
      };
}
