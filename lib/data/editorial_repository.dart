import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/editorial_content.dart';

class EditorialRepository {
  static const _paths = <String, String>{
    'era': 'assets/data/editorial_eras.json',
    'personaje': 'assets/data/editorial_personajes.json',
    'tradicion': 'assets/data/editorial_tradiciones.json',
    'gastronomia': 'assets/data/editorial_gastronomia.json',
    'musica': 'assets/data/editorial_musica.json',
    'geografia': 'assets/data/editorial_geografia.json',
  };

  static final Map<String, List<EditorialContent>> _cache = {};

  /// Returns the item with [id] in [category], or null if not found.
  /// Never throws — missing files or categories return null silently.
  static Future<EditorialContent?> findById(
      String id, String category) async {
    final items = await _loadCategory(category);
    try {
      return items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns all items for [category], sorted by orden.
  /// Returns an empty list if the category has no JSON file or the file is missing.
  static Future<List<EditorialContent>> loadCategory(String category) =>
      _loadCategory(category);

  static Future<List<EditorialContent>> _loadCategory(String category) async {
    if (_cache.containsKey(category)) return _cache[category]!;

    final path = _paths[category];
    if (path == null) return const [];

    try {
      final raw = await rootBundle.loadString(path);
      final list = jsonDecode(raw) as List<dynamic>;
      final items = list
          .map((e) => EditorialContent.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
      _cache[category] = items;
      return items;
    } catch (_) {
      return const [];
    }
  }

  static void clearCache() => _cache.clear();
}
