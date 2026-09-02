import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigation.dart';
import '../data/historia_stages_repository.dart';
import '../models/historia_article.dart';
import '../models/historia_stage.dart';
import '../models/timeline_item.dart';
import '../providers/language_provider.dart';
import '../widgets/historia_timeline.dart';
import 'cultural_map_screen.dart';

enum _ExplorerView { map, timeline }

/// Pestaña "Mapa" de la barra de navegación principal: alterna entre la
/// vista de mapa cultural (`CulturalMapBody`) y la línea de tiempo histórica
/// (`HistoriaTimeline`), ambas ya existentes y reutilizadas tal cual.
class MapTimelineScreen extends StatefulWidget {
  const MapTimelineScreen({super.key});

  @override
  State<MapTimelineScreen> createState() => _MapTimelineScreenState();
}

class _MapTimelineScreenState extends State<MapTimelineScreen> {
  _ExplorerView _view = _ExplorerView.map;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final t = context.read<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.t('cultural_map.eyebrow'),
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ocre,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.t('cultural_map.title'),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cremaPergamino,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<_ExplorerView>(
                    segments: [
                      ButtonSegment(
                        value: _ExplorerView.map,
                        label: Text(t.t('cultural_map.view_map')),
                        icon: const Icon(Icons.map_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: _ExplorerView.timeline,
                        label: Text(t.t('cultural_map.view_timeline')),
                        icon: const Icon(Icons.timeline_rounded, size: 16),
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (selection) =>
                        setState(() => _view = selection.first),
                    style: SegmentedButton.styleFrom(
                      backgroundColor: AppColors.marronProfundo,
                      foregroundColor: AppColors.cremaPergamino.withValues(alpha: 0.6),
                      selectedBackgroundColor: AppColors.ocre.withValues(alpha: 0.2),
                      selectedForegroundColor: AppColors.ocre,
                      side: BorderSide(color: AppColors.ocre.withValues(alpha: 0.3)),
                      textStyle: GoogleFonts.lato(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _view == _ExplorerView.map
                  ? const SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 4, 20, 90),
                      child: CulturalMapBody(),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 90),
                      child: HistoriaTimeline(
                        lang: lang,
                        onItemTap: (item) => _openTimelineItem(context, item),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTimelineItem(BuildContext context, TimelineItem item) async {
    final stageId = item.stageId;
    if (stageId == null) return;
    final stages = await HistoriaStagesRepository.loadStages();
    final stage = stages.cast<HistoriaStage?>().firstWhere(
          (s) => s?.id == stageId,
          orElse: () => null,
        );
    final articles = await HistoriaStagesRepository.loadArticlesForStage(stageId);
    final article = articles.cast<HistoriaArticle?>().firstWhere(
          (a) => a?.id == item.articleId,
          orElse: () => null,
        );
    if (!context.mounted || article == null) return;
    AppNavigation.openHistoriaArticle(
      context,
      article: article,
      allArticles: articles,
      stage: stage,
    );
  }
}
