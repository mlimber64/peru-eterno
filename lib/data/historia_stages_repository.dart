import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/historia_article.dart';
import '../models/historia_stage.dart';
import '../models/timeline_item.dart';

class HistoriaStagesRepository {
  static const _stagesPath = 'assets/data/historia_stages.json';

  static const _articlesPaths = {
    'peru_prehispanico': 'assets/data/historia_prehispanica.json',
    'conquista_spagnola': 'assets/data/historia_conquista.json',
    'vicereame_peru': 'assets/data/historia_vicereame.json',
    'indipendenza': 'assets/data/historia_indipendenza.json',
  };

  static List<HistoriaStage>? _stagesCache;
  static final Map<String, List<HistoriaArticle>> _articlesCache = {};

  static Future<List<HistoriaStage>> loadStages() async {
    if (_stagesCache != null) return _stagesCache!;
    final raw = await rootBundle.loadString(_stagesPath);
    final list = jsonDecode(raw) as List<dynamic>;
    _stagesCache = list
        .map((e) => HistoriaStage.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    return _stagesCache!;
  }

  static Future<List<HistoriaArticle>> loadArticlesForStage(
      String stageId) async {
    if (_articlesCache.containsKey(stageId)) return _articlesCache[stageId]!;
    final path = _articlesPaths[stageId];
    if (path == null) return [];
    final raw = await rootBundle.loadString(path);
    final list = jsonDecode(raw) as List<dynamic>;
    final articles = list
        .map((e) => HistoriaArticle.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    _articlesCache[stageId] = articles;
    return articles;
  }

  static void clearCache() {
    _stagesCache = null;
    _articlesCache.clear();
    _timelineCache = null;
  }

  static const _timelinePath = 'assets/data/timeline_items.json';
  static List<TimelineItem>? _timelineCache;

  static Future<List<TimelineItem>> loadTimeline() async {
    if (_timelineCache != null) return _timelineCache!;
    final raw = await rootBundle.loadString(_timelinePath);
    final list = jsonDecode(raw) as List<dynamic>;
    _timelineCache = list
        .map((e) => TimelineItem.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));
    return _timelineCache!;
  }

  static List<String> carouselImagesForStage(String stageId) =>
      switch (stageId) {
        'peru_prehispanico' => const [
            'assets/images/banners/caral-desertico.jpg',
            'assets/images/banners/machu-picchu-amanecer.jpg',
            'assets/images/banners/sacerdote-ceremonial-andino.jpg',
          ],
        _ => const [],
      };
}
