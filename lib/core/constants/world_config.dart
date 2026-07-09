import 'package:flutter/material.dart';

class WorldEntry {
  final String id;
  final String category;
  final Color accentColor;
  final Color accentColorDark;
  final IconData icon;
  final String emoji;
  final Map<String, String> title;
  final Map<String, String> description;

  const WorldEntry({
    required this.id,
    required this.category,
    required this.accentColor,
    required this.accentColorDark,
    required this.icon,
    required this.emoji,
    required this.title,
    required this.description,
  });

  String titleFor(String lang) => title[lang] ?? title['es']!;
  String descriptionFor(String lang) => description[lang] ?? description['es']!;
}

class WorldConfig {
  static const List<WorldEntry> worlds = [
    WorldEntry(
      id: 'historia',
      category: 'era',
      accentColor: Color(0xFFC1440E),
      accentColorDark: Color(0xFF5A0D03),
      icon: Icons.history_edu_rounded,
      emoji: '🏛',
      title: {'es': 'Historia', 'en': 'History', 'it': 'Storia'},
      description: {
        'es': 'Civilizaciones, cronologías, imperios',
        'en': 'Civilizations, timelines, empires',
        'it': 'Civiltà, cronologie, imperi',
      },
    ),
    WorldEntry(
      id: 'cultura',
      category: 'tradicion',
      accentColor: Color(0xFF2D6A4F),
      accentColorDark: Color(0xFF0D2418),
      icon: Icons.self_improvement_rounded,
      emoji: '🎭',
      title: {
        'es': 'Cultura Viva',
        'en': 'Living Culture',
        'it': 'Cultura Viva',
      },
      description: {
        'es': 'Tradiciones, danzas, festividades',
        'en': 'Traditions, dances, festivities',
        'it': 'Tradizioni, danze, festività',
      },
    ),
    WorldEntry(
      id: 'sabores',
      category: 'gastronomia',
      accentColor: Color(0xFFC8860A),
      accentColorDark: Color(0xFF3E2503),
      icon: Icons.restaurant_rounded,
      emoji: '🍽',
      title: {
        'es': 'Sabores del Perú',
        'en': "Peru's Flavors",
        'it': 'Sapori del Perù',
      },
      description: {
        'es': 'Gastronomía ancestral y contemporánea',
        'en': 'Ancestral and contemporary gastronomy',
        'it': 'Gastronomia ancestrale e contemporanea',
      },
    ),
    WorldEntry(
      id: 'musica',
      category: 'musica',
      accentColor: Color(0xFF6B3FA0),
      accentColorDark: Color(0xFF1E0D30),
      icon: Icons.music_note_rounded,
      emoji: '🎵',
      title: {'es': 'Música y Arte', 'en': 'Music & Art', 'it': 'Musica e Arte'},
      description: {
        'es': 'Ritmos, instrumentos, poesía',
        'en': 'Rhythms, instruments, poetry',
        'it': 'Ritmi, strumenti, poesia',
      },
    ),
    WorldEntry(
      id: 'territorios',
      category: 'geografia',
      accentColor: Color(0xFF1A5276),
      accentColorDark: Color(0xFF071622),
      icon: Icons.terrain_rounded,
      emoji: '🌄',
      title: {
        'es': 'Territorios Sagrados',
        'en': 'Sacred Territories',
        'it': 'Territori Sacri',
      },
      description: {
        'es': 'Andes, costa, selva, maravillas',
        'en': 'Andes, coast, jungle, wonders',
        'it': 'Ande, costa, foresta, meraviglie',
      },
    ),
  ];

  static WorldEntry? findById(String id) {
    try {
      return worlds.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  static WorldEntry? forCategory(String category) {
    try {
      return worlds.firstWhere((w) => w.category == category);
    } catch (_) {
      return null;
    }
  }
}
