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

  /// Categorías bloqueadas con el aviso "Próximamente" en esta versión. Se
  /// mantienen visibles en la UI en vez de quitarse — ver
  /// [[widgets/coming_soon.dart]] y su uso en
  /// HomeScreen/ExploreScreen/WorldScreen. **Casi** todo pasa por
  /// [isComingSoon], pero ojo: `_PersonajeDiaSection` de HomeScreen tiene su
  /// propia tarjeta y también hay que mirarlo al cambiar esta lista.
  ///
  /// Decisión de producto (2026-09-02): la v1.0 sale **solo con Historia**.
  /// El contenido de estas cinco está terminado y verificado —27 fichas en
  /// `assets/data/editorial_*.json`, trilingües y con imagen, y las mismas
  /// filas en `content_items` de Supabase—, así que quitar una de aquí la
  /// publica al instante, sin más trabajo.
  static const Set<String> comingSoonCategories = {
    'personaje',
    'tradicion',
    'gastronomia',
    'musica',
    'geografia',
  };

  static bool isComingSoon(String category) =>
      comingSoonCategories.contains(category);
}
