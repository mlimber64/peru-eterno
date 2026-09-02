import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/interactive_story.dart';

/// Manifiesto de historias interactivas disponibles. Añadir aquí la ruta de
/// cada nuevo archivo JSON creado en `assets/data-refactor/stories/` (mismo
/// patrón que `HistoriaStagesRepository._refactoredStageAssets`).
class InteractiveStoryRepository {
  static const List<String> storyAssets = [
    'assets/data-refactor/stories/chasqui_adventure.json',
    'assets/data-refactor/stories/cronista_cajamarca_adventure.json',
  ];

  static List<InteractiveStory>? _cache;

  static Future<List<InteractiveStory>> loadAllStories() async {
    if (_cache != null) return _cache!;
    final stories = <InteractiveStory>[];
    for (final path in storyAssets) {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      stories.add(InteractiveStory.fromJson(decoded));
    }
    _cache = stories;
    return stories;
  }

  static Future<InteractiveStory?> loadStory(String id) async {
    final stories = await loadAllStories();
    return stories.cast<InteractiveStory?>().firstWhere(
          (s) => s?.id == id,
          orElse: () => null,
        );
  }

  static void clearCache() => _cache = null;
}
