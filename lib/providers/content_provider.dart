import 'package:flutter/foundation.dart';

import '../data/content_repository_remote.dart';
import '../models/editorial_content.dart';

/// Estado del contenido editorial remoto (Supabase) con caché offline-first.
///
/// El idioma NO se decide aquí: se guarda el mapa multiidioma completo y la UI
/// elige con `item.tituloFor(lang)`. Cambiar de idioma no re-descarga nada.
class ContentProvider extends ChangeNotifier {
  final RemoteContentRepository _repo;
  ContentProvider(this._repo);

  final Map<String, List<EditorialContent>> _byCategory = {};
  final Set<String> _loading = {};
  final Set<String> _offline = {};

  /// Ítems cacheados/cargados de [category] (vacío si aún no hay).
  List<EditorialContent> itemsFor(String category) =>
      _byCategory[category] ?? const [];

  /// `true` mientras se carga y todavía no hay nada que mostrar.
  bool isLoading(String category) =>
      _loading.contains(category) && itemsFor(category).isEmpty;

  /// `true` si la última carga de [category] no pudo contactar Supabase
  /// (se está sirviendo caché o seed). Útil para un aviso sutil en la UI.
  bool isOffline(String category) => _offline.contains(category);

  /// Carga [category] (idempotente). Emite dos veces: caché instantánea y,
  /// luego, datos frescos de Supabase.
  Future<void> ensureLoaded(String category) async {
    if (_byCategory.containsKey(category) || _loading.contains(category)) return;
    _loading.add(category);
    notifyListeners();

    // Fase 1 — caché en disco (UI inmediata, también offline).
    final cached = await _repo.cached(category);
    if (cached.isNotEmpty) {
      _byCategory[category] = cached;
      notifyListeners();
    }

    // Fase 2 — revalidar contra Supabase.
    try {
      _byCategory[category] = await _repo.refresh(category);
      _offline.remove(category);
    } catch (_) {
      _offline.add(category);
      // Sin red y sin caché previa → respaldo embebido.
      if (cached.isEmpty) {
        _byCategory[category] = await _repo.seed(category);
      }
    } finally {
      _loading.remove(category);
      notifyListeners();
    }
  }

  /// Refresco manual (pull-to-refresh).
  Future<void> refresh(String category) async {
    try {
      _byCategory[category] = await _repo.refresh(category);
      _offline.remove(category);
    } catch (_) {
      _offline.add(category); // mantiene lo cacheado
    }
    notifyListeners();
  }
}
