import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Caché local persistente (sqflite) para el contenido remoto.
///
/// Guarda cada fila como JSON crudo bajo (source, row_id) y un cursor de
/// sincronización por tabla. Permite servir contenido sin red.
///
/// Nota: sqflite soporta Android/iOS. En escritorio requeriría
/// `sqflite_common_ffi`; la app de producción corre en móvil.
class LocalContentCache {
  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'peru_eterno_content.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE rows(
            source   TEXT NOT NULL,
            row_id   TEXT NOT NULL,
            payload  TEXT NOT NULL,
            orden    INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (source, row_id)
          )''');
        await db.execute('''
          CREATE TABLE sync_meta(
            source    TEXT PRIMARY KEY,
            last_sync TEXT
          )''');
      },
    );
  }

  /// Cursor de la última sincronización para [source] (o null si nunca).
  Future<DateTime?> lastSync(String source) async {
    final db = await _database;
    final r = await db.query('sync_meta',
        where: 'source = ?', whereArgs: [source], limit: 1);
    final v = r.isNotEmpty ? r.first['last_sync'] as String? : null;
    return v == null ? null : DateTime.tryParse(v);
  }

  /// Inserta/actualiza filas (upsert) y avanza el cursor de sync al
  /// `updated_at` más reciente recibido.
  Future<void> upsert(String source, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await _database;
    final batch = db.batch();
    DateTime? maxUpdated = await lastSync(source);

    for (final row in rows) {
      batch.insert(
        'rows',
        {
          'source': source,
          'row_id': row['id'] as String,
          'payload': jsonEncode(row),
          'orden': (row['orden'] as int?) ?? 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final u = DateTime.tryParse(row['updated_at']?.toString() ?? '');
      if (u != null && (maxUpdated == null || u.isAfter(maxUpdated))) {
        maxUpdated = u;
      }
    }

    if (maxUpdated != null) {
      batch.insert(
        'sync_meta',
        {'source': source, 'last_sync': maxUpdated.toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Devuelve todas las filas cacheadas de [source], ordenadas por `orden`.
  Future<List<Map<String, dynamic>>> readAll(String source) async {
    final db = await _database;
    final r = await db.query('rows',
        where: 'source = ?', whereArgs: [source], orderBy: 'orden ASC');
    return r
        .map((e) => jsonDecode(e['payload'] as String) as Map<String, dynamic>)
        .toList();
  }
}
