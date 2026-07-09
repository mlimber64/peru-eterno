import '../models/editorial_content.dart';
import 'editorial_repository.dart';
import 'local/local_content_cache.dart';
import 'remote/supabase_content_api.dart';

/// Repositorio offline-first del contenido editorial.
///
/// Estrategia stale-while-revalidate:
///  • [cached]  → lo que haya en disco AHORA (instantáneo, offline).
///  • [refresh] → sincroniza con Supabase (incremental) y devuelve lo nuevo.
///  • [seed]    → respaldo desde los assets/data/*.json embebidos (primer
///                arranque sin red, sin caché previa).
class RemoteContentRepository {
  final SupabaseContentApi _api;
  final LocalContentCache _cache;
  RemoteContentRepository(this._api, this._cache);

  static const String table = 'content_items';

  /// Contenido cacheado en disco para [category] (instantáneo, sin red).
  Future<List<EditorialContent>> cached(String category) async {
    final rows = await _cache.readAll(table);
    return rows
        .where((r) => r['category'] == category)
        .map(EditorialContent.fromJson)
        .toList();
  }

  /// Sincroniza incrementalmente con Supabase y devuelve [category] ya fresca.
  Future<List<EditorialContent>> refresh(String category) async {
    final since = await _cache.lastSync(table);
    final rows = await _api.fetchSince(table, since: since);
    await _cache.upsert(table, rows);
    return cached(category);
  }

  /// Respaldo offline del primer arranque: assets/data/editorial_*.json.
  Future<List<EditorialContent>> seed(String category) =>
      EditorialRepository.loadCategory(category);
}
