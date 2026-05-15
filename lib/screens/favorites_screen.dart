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
import '../providers/favorites_provider.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/cinematic_card.dart';
import '../widgets/wiki_cinematic_card.dart';
import 'content_detail_screen.dart';
import 'era_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  List<ContentItem> _resolveItems(Set<String> ids) {
    final items = <ContentItem>[];
    for (final id in ids) {
      // Check eras
      final era = ErasRepository.allEras.cast<EraModel?>().firstWhere(
            (e) => e?.id == id,
            orElse: () => null,
          );
      if (era != null) {
        items.add(ContentItem(
          id: era.id,
          category: 'era',
          wikipediaSlug: era.wikipediaSlug,
          isPremium: era.isPremium,
        ));
        continue;
      }
      // Check content
      final item = ContentRepository.findById(id);
      if (item != null) items.add(item);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final isPremium = context.watch<PremiumProvider>().isPremium;
    final favorites = context.watch<FavoritesProvider>().favorites;
    final items = _resolveItems(favorites);

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _eyebrow(lang),
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ocre,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _title(lang),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cremaPergamino,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                        final card = era != null
                            ? CinematicCard(
                                assetImagePath:
                                    era.imageAssetPath(era.imageFilenames.first),
                                accentColor: era.accentColor,
                                title: t('eras.${era.id}.title'),
                                subtitle: t('eras.${era.id}.period'),
                                isPremium: isLocked,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(
                                        builder: (_) => EraDetailScreen(era: era))),
                              )
                            : WikiCinematicCard(
                                item: item,
                                subtitle: CategoryConfigs.labelOf(item.category, lang),
                                isPremium: isLocked,
                                onTap: () => Navigator.push(context,
                                    MaterialPageRoute(
                                        builder: (_) => ContentDetailScreen(item: item))),
                              );

                        return Stack(
                          children: [
                            card,
                            // Remove from favorites button
                            Positioned(
                              top: 8,
                              left: 8,
                              child: GestureDetector(
                                onTap: () => context
                                    .read<FavoritesProvider>()
                                    .toggle(item.id),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    size: 14,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(
                              duration: 400.ms,
                              delay: Duration(milliseconds: i * 60),
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
          Icon(
            Icons.favorite_border_rounded,
            size: 64,
            color: AppColors.cremaPergamino.withOpacity(0.1),
          ),
          const SizedBox(height: 20),
          Text(
            _emptyTitle(lang),
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              color: AppColors.cremaPergamino.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _emptySubtitle(lang),
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 13,
              color: AppColors.cremaPergamino.withOpacity(0.25),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _eyebrow(String lang) => switch (lang) {
        'en' => 'MY COLLECTION',
        'es' => 'MI COLECCIÓN',
        _ => 'LA MIA COLLEZIONE',
      };
  String _title(String lang) => switch (lang) {
        'en' => 'Saved',
        'es' => 'Guardados',
        _ => 'Salvati',
      };
  String _emptyTitle(String lang) => switch (lang) {
        'en' => 'Nothing saved yet',
        'es' => 'Aún no hay guardados',
        _ => 'Niente ancora salvato',
      };
  String _emptySubtitle(String lang) => switch (lang) {
        'en' => 'Tap the heart icon on any\narticle to save it here',
        'es' => 'Toca el corazón en cualquier\nartículo para guardarlo aquí',
        _ => 'Tocca il cuore su qualsiasi\narticolo per salvarlo',
      };
}
