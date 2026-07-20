// Repositorio de artículos editoriales de Historia preispanica.
//
// Fuente enriquecida y multilenguaje: los 8 hitos de la Historia Prehispánica
// viven ahora en archivos individuales dentro de
// assets/data-refactor/peru-prehispanico/ (uno por civilización).
// Se cargan una sola vez y se cachean en memoria. Contenido 100% offline.
//
// Sistema anterior (ErasRepository + WikipediaService) sigue intacto
// y puede coexistir con este repositorio.

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/historia_article.dart';

class HistoriaRepository {
  /// Archivos individuales de cada hito prehispánico (contenido enriquecido).
  /// Cada archivo contiene UN objeto JSON (no un array).
  /// El orden final de la lista lo determina el campo `orden` de cada archivo.
  static const List<String> prehispanicoAssets = [
    'assets/data-refactor/peru-prehispanico/pp-caral.json',
    'assets/data-refactor/peru-prehispanico/pp-chavin.json',
    'assets/data-refactor/peru-prehispanico/pp-paracas.json',
    'assets/data-refactor/peru-prehispanico/pp-nazca.json',
    'assets/data-refactor/peru-prehispanico/pp-moche.json',
    'assets/data-refactor/peru-prehispanico/pp-wari.json',
    'assets/data-refactor/peru-prehispanico/pp-chimu.json',
    'assets/data-refactor/peru-prehispanico/pp-incas.json',
  ];

  static List<HistoriaArticle>? _cache;

  /// Carga y devuelve todos los artículos ordenados por [orden].
  /// La primera llamada lee los assets; las siguientes usan el cache en memoria.
  static Future<List<HistoriaArticle>> loadAll() async {
    if (_cache != null) return _cache!;

    final articles = <HistoriaArticle>[];
    for (final path in prehispanicoAssets) {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      // Se soporta tanto un objeto único (formato nuevo) como un array
      // (por compatibilidad, si algún archivo agrupara varios hitos).
      if (decoded is List) {
        articles.addAll(decoded
            .map((e) => HistoriaArticle.fromJson(e as Map<String, dynamic>)));
      } else if (decoded is Map<String, dynamic>) {
        articles.add(HistoriaArticle.fromJson(decoded));
      }
    }

    articles.sort((a, b) => a.orden.compareTo(b.orden));
    _cache = articles;
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
