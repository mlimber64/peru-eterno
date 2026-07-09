// Repositorio de artículos editoriales de Historia preispanica.
// Carga assets/data/historia_prehispanica.json una sola vez y lo cachea en memoria.
// No depende de red ni de WikipediaService — contenido 100% offline.
//
// Sistema anterior (ErasRepository + WikipediaService) sigue intacto
// y puede coexistir con este repositorio.

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/historia_article.dart';

class HistoriaRepository {
  static const String _assetPath = 'assets/data/historia_prehispanica.json';

  static List<HistoriaArticle>? _cache;

  /// Carga y devuelve todos los artículos ordenados por [orden].
  /// La primera llamada lee el asset; las siguientes usan el cache en memoria.
  static Future<List<HistoriaArticle>> loadAll() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString(_assetPath);
    final list = jsonDecode(raw) as List<dynamic>;

    _cache = list
        .map((e) => HistoriaArticle.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.orden.compareTo(b.orden));

    return _cache!;
  }

  /// Devuelve un artículo por id, o null si no existe.
  static Future<HistoriaArticle?> findById(String id) async {
    final all = await loadAll();
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Invalida el cache (útil en desarrollo o si el asset cambia en caliente).
  static void clearCache() => _cache = null;
}
