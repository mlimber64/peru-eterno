import 'package:supabase_flutter/supabase_flutter.dart';

/// Fuente de datos remota: lee contenido de Supabase (PostgREST).
/// Soporta sincronización incremental por `updated_at`.
///
/// El cliente es opcional: si la app se compiló sin las variables de Supabase,
/// [fetchSince] lanza y el repositorio cae a la caché/seed locales.
class SupabaseContentApi {
  final SupabaseClient? _db;
  SupabaseContentApi(this._db);

  /// Trae filas de [table] modificadas después de [since]. Si [since] es null,
  /// devuelve la tabla completa. Ordenadas por `orden` ascendente.
  Future<List<Map<String, dynamic>>> fetchSince(
    String table, {
    DateTime? since,
  }) async {
    final db = _db;
    if (db == null) {
      throw StateError('Supabase no inicializado (faltan SUPABASE_URL/KEY).');
    }
    final base = db.from(table).select();
    final filtered =
        since != null ? base.gt('updated_at', since.toIso8601String()) : base;
    final data = await filtered.order('orden', ascending: true);
    return (data as List).cast<Map<String, dynamic>>();
  }
}
