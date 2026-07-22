import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/historia_article.dart';
import '../models/historia_stage.dart';
import '../models/timeline_item.dart';
import 'historia_repository.dart';

class HistoriaStagesRepository {
  static const _stagesPath = 'assets/data/historia_stages.json';

  // Todas las etapas usan contenido enriquecido en archivos individuales por
  // hito (un JSON por artículo, multilenguaje, en assets/data-refactor/). El
  // orden final lo determina el campo `orden` de cada archivo.
  static const _refactoredStageAssets = <String, List<String>>{
    'conquista_spagnola': [
      'assets/data-refactor/conquista-espanola/ce-guerra-civil.json',
      'assets/data-refactor/conquista-espanola/ce-cajamarca.json',
      'assets/data-refactor/conquista-espanola/ce-vilcabamba.json',
    ],
    'vicereame_peru': [
      'assets/data-refactor/virreinato-peru/vp-lima-virreinal.json',
      'assets/data-refactor/virreinato-peru/vp-sincretismo-arte.json',
      'assets/data-refactor/virreinato-peru/vp-terremoto-tapadas.json',
    ],
    'indipendenza': [
      'assets/data-refactor/independencia-peru/ip-tupac-amaru.json',
      'assets/data-refactor/independencia-peru/ip-san-martin.json',
      'assets/data-refactor/independencia-peru/ip-junin-ayacucho.json',
    ],
    'republica_peru': [
      'assets/data-refactor/republica-peru/rp-guano-dos-de-mayo.json',
      'assets/data-refactor/republica-peru/rp-grau-huascar.json',
      'assets/data-refactor/republica-peru/rp-bolognesi-caceres.json',
    ],
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

    // Prehispánico: hitos enriquecidos (Caral, Chavín, Paracas, Nazca, Moche,
    // Wari, Chimú, Incas) desde assets/data-refactor/peru-prehispanico/.
    if (stageId == 'peru_prehispanico') {
      final articles = await HistoriaRepository.loadAll();
      _articlesCache[stageId] = articles;
      return articles;
    }

    // Etapas migradas a archivos individuales por hito.
    final refactoredPaths = _refactoredStageAssets[stageId];
    if (refactoredPaths == null) return [];
    final articles = await _loadIndividualFiles(refactoredPaths);
    _articlesCache[stageId] = articles;
    return articles;
  }

  /// Carga una lista de archivos JSON individuales (uno o varios hitos por
  /// archivo) y devuelve los artículos ordenados por [orden]. Soporta tanto un
  /// objeto único (formato nuevo) como un array por compatibilidad.
  static Future<List<HistoriaArticle>> _loadIndividualFiles(
      List<String> paths) async {
    final articles = <HistoriaArticle>[];
    for (final path in paths) {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        articles.addAll(decoded
            .map((e) => HistoriaArticle.fromJson(e as Map<String, dynamic>)));
      } else if (decoded is Map<String, dynamic>) {
        articles.add(HistoriaArticle.fromJson(decoded));
      }
    }
    articles.sort((a, b) => a.orden.compareTo(b.orden));
    return articles;
  }

  /// Todos los capítulos de Historia (las 5 etapas, 20 artículos en total),
  /// en orden canónico: por etapa (`orden`) y, dentro de cada una, por
  /// artículo (`orden`). Usado por [DailyStoryProvider] para elegir de forma
  /// determinista y uniforme la "Historia del Día".
  static Future<List<(HistoriaArticle, HistoriaStage)>>
      loadAllArticles() async {
    final stages = await loadStages();
    final all = <(HistoriaArticle, HistoriaStage)>[];
    for (final stage in stages) {
      final articles = await loadArticlesForStage(stage.id);
      for (final article in articles) {
        all.add((article, stage));
      }
    }
    return all;
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
        'vicereame_peru' => const [
            'assets/images/virreinato/virreinato_1.jpg',
            'assets/images/virreinato/virreinato_2.jpg',
            'assets/images/virreinato/virreinato_3.jpg',
          ],
        'indipendenza' => const [
            'assets/images/independencia/independencia_1.jpg',
            'assets/images/independencia/independencia_2.jpg',
            'assets/images/independencia/independencia_3.jpg',
          ],
        _ => const [],
      };
}
