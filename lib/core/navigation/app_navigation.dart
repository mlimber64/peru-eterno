import 'package:flutter/material.dart';

import '../../data/historia_stages_repository.dart';
import '../../models/content_item.dart';
import '../../models/era_model.dart';
import '../../models/historia_article.dart';
import '../../models/historia_stage.dart';
import '../../screens/content_detail_screen.dart';
import '../../screens/era_detail_screen.dart';
import '../../screens/historia_article_detail_screen.dart';
import '../../screens/historia_subtopics_screen.dart';
import '../../screens/premium_screen.dart';

class AppNavigation {
  static Future<void> openEra(
    BuildContext context,
    EraModel era, {
    bool isLocked = false,
  }) async {
    if (isLocked) {
      return openPremium(context);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EraDetailScreen(era: era)),
    );
  }

  static Future<void> openContent(
    BuildContext context,
    ContentItem item, {
    bool isLocked = false,
  }) async {
    if (isLocked) {
      return openPremium(context);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContentDetailScreen(item: item)),
    );
  }

  static Future<void> openPremium(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
  }

  static Future<void> openHistoriaStage(
    BuildContext context,
    HistoriaStage stage,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoriaSubtopicsScreen(
          stage: stage,
          carouselImages:
              HistoriaStagesRepository.carouselImagesForStage(stage.id),
        ),
      ),
    );
  }

  static Future<void> openHistoriaArticle(
    BuildContext context, {
    required HistoriaArticle article,
    required List<HistoriaArticle> allArticles,
    HistoriaStage? stage,
    List<String>? carouselImages,
    bool replace = false,
  }) async {
    final resolvedStage = stage ?? await _resolveStage(article.parentStageId);
    if (!context.mounted) return;

    final route = MaterialPageRoute(
      builder: (_) => HistoriaArticleDetailScreen(
        article: article,
        allArticles: allArticles,
        stage: resolvedStage,
        carouselImages: carouselImages ??
            (resolvedStage != null
                ? HistoriaStagesRepository.carouselImagesForStage(
                    resolvedStage.id,
                  )
                : const []),
      ),
    );

    if (replace) {
      await Navigator.pushReplacement(context, route);
      return;
    }
    await Navigator.push(context, route);
  }

  static Future<HistoriaStage?> _resolveStage(String? stageId) async {
    final id = (stageId == null || stageId.isEmpty || stageId == 'unknown')
        ? 'peru_prehispanico'
        : stageId;
    final stages = await HistoriaStagesRepository.loadStages();
    try {
      return stages.firstWhere((stage) => stage.id == id);
    } catch (_) {
      return null;
    }
  }
}
