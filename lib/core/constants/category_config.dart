import 'package:flutter/material.dart';

class CategoryConfig {
  final Color color;
  final IconData icon;
  final Map<String, String> labels;

  const CategoryConfig({
    required this.color,
    required this.icon,
    required this.labels,
  });

  String labelFor(String lang) => labels[lang] ?? labels['es']!;
}

class CategoryConfigs {
  static const Map<String, CategoryConfig> _configs = {
    'era': CategoryConfig(
      color: Color(0xFFC8860A),
      icon: Icons.history_edu_rounded,
      labels: {'es': 'Historia', 'en': 'History', 'it': 'Storia'},
    ),
    'personaje': CategoryConfig(
      color: Color(0xFF8B4513),
      icon: Icons.person_rounded,
      labels: {'es': 'Personajes', 'en': 'People', 'it': 'Persone'},
    ),
    'tradicion': CategoryConfig(
      color: Color(0xFF2D6A4F),
      icon: Icons.self_improvement_rounded,
      labels: {'es': 'Tradiciones', 'en': 'Traditions', 'it': 'Tradizioni'},
    ),
    'gastronomia': CategoryConfig(
      color: Color(0xFFC1440E),
      icon: Icons.restaurant_rounded,
      labels: {'es': 'Gastronomía', 'en': 'Gastronomy', 'it': 'Gastronomia'},
    ),
    'musica': CategoryConfig(
      color: Color(0xFF6B3FA0),
      icon: Icons.music_note_rounded,
      labels: {'es': 'Música', 'en': 'Music', 'it': 'Musica'},
    ),
    'geografia': CategoryConfig(
      color: Color(0xFF1565C0),
      icon: Icons.terrain_rounded,
      labels: {'es': 'Geografía', 'en': 'Geography', 'it': 'Geografia'},
    ),
  };

  static CategoryConfig of(String category) =>
      _configs[category] ?? _configs['era']!;

  static Color colorOf(String category) => of(category).color;
  static IconData iconOf(String category) => of(category).icon;
  static String labelOf(String category, String lang) =>
      of(category).labelFor(lang);

  /// Categorías cuyo contenido curado todavía no está listo para publicarse.
  /// Se mantienen visibles en la UI pero bloqueadas con un aviso
  /// "Próximamente" en vez de quitarse — ver [[widgets/coming_soon.dart]] y su
  /// uso en HomeScreen/ExploreScreen/WorldScreen. Todo pasa por
  /// [isComingSoon], así que añadir o quitar una categoría aquí basta.
  ///
  /// **Vacío desde el 2026-09-02.** Contenía personaje, tradicion,
  /// gastronomia, musica y geografia, bloqueadas por una "mezcla incompleta
  /// de contenido editorial + fallback de Wikipedia" que ya no existe: las 27
  /// fichas están completas en `assets/data/editorial_*.json` (título,
  /// subtítulo y contenido en es/it/en, con sus imágenes) y las mismas 29
  /// filas están en `content_items` de Supabase. Como
  /// `ContentDetailScreen._loadWikipediaContent` busca primero en los assets
  /// por (id, categoría) y solo cae a Wikipedia si no encuentra nada, y los
  /// ids del servidor coinciden 1:1 con los de los assets, ninguna de estas
  /// fichas llega a pedirle nada a Wikipedia.
  ///
  /// El mecanismo se conserva a propósito para la próxima categoría que se
  /// empiece antes de terminarla.
  static const Set<String> comingSoonCategories = {};

  static bool isComingSoon(String category) =>
      comingSoonCategories.contains(category);
}
