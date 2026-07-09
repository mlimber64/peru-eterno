// ============================================================================
//  Perú Eterno — Seed de Supabase
// ----------------------------------------------------------------------------
//  Lee los JSON de assets/data/ (y los pines del mapa, extraídos del código)
//  y los sube a Supabase mediante la API REST (PostgREST) con upsert.
//
//  Requisitos: solo usa dart:io, dart:convert y package:http (ya es
//  dependencia del proyecto). NO necesita Flutter ni paquetes nuevos.
//
//  Uso (PowerShell):
//    $env:SUPABASE_URL="https://xxxx.supabase.co"
//    $env:SUPABASE_SERVICE_ROLE_KEY="eyJhbGciOi..."   # clave service_role
//    dart run tool/seed_supabase.dart
//
//  Uso (bash):
//    SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... dart run tool/seed_supabase.dart
//
//  ⚠️ La service_role key OMITE el RLS (permite escritura). Es secreta:
//     úsala solo localmente, NUNCA la incluyas en la app ni la subas a git.
//
//  Idempotente: usa upsert (merge por clave primaria); se puede re-ejecutar.
//  Respeta el orden de carga exigido por las claves foráneas.
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _dataDir = 'assets/data';

/// Archivos editoriales → tabla content_items.
const _editorialFiles = <String>[
  'editorial_eras.json',
  'editorial_personajes.json',
  'editorial_tradiciones.json',
  'editorial_gastronomia.json',
  'editorial_musica.json',
  'editorial_geografia.json',
];

/// Archivo de artículos → id de la etapa padre (fuente de verdad de la FK).
const _articleFiles = <String, String>{
  'historia_prehispanica.json': 'peru_prehispanico',
  'historia_conquista.json': 'conquista_spagnola',
  'historia_vicereame.json': 'vicereame_peru',
  'historia_indipendenza.json': 'indipendenza',
};

/// Pines del mapa cultural (extraídos de lib/screens/cultural_map_screen.dart).
/// Offset(dx,dy) → pos_x/pos_y. AppColors resueltos a hex ARGB.
const _mapPoints = <Map<String, dynamic>>[
  {
    'id': 'caral', 'orden': 1,
    'name': {'it': 'Caral', 'es': 'Caral', 'en': 'Caral'},
    'region': {'it': 'Lima, valle di Supe', 'es': 'Lima, valle de Supe', 'en': 'Lima, Supe Valley'},
    'period': {'it': 'Civilta arcaica', 'es': 'Civilizacion arcaica', 'en': 'Archaic civilization'},
    'image_asset': 'assets/images/caral/caral_1.jpg',
    'pos_x': 0.36, 'pos_y': 0.33, 'accent_color': 'FFD4A854',
    'historia_article_id': 'caral',
  },
  {
    'id': 'chavin', 'orden': 2,
    'name': {'it': 'Chavin', 'es': 'Chavin', 'en': 'Chavin'},
    'region': {'it': 'Ancash, Ande settentrionali', 'es': 'Ancash, sierra norte', 'en': 'Ancash, northern Andes'},
    'period': {'it': 'Centro cerimoniale', 'es': 'Centro ceremonial', 'en': 'Ceremonial center'},
    'image_asset': 'assets/images/banners/sacerdote-ceremonial-andino.jpg',
    'pos_x': 0.48, 'pos_y': 0.27, 'accent_color': 'FFC1440E',
    'historia_article_id': 'chavin',
  },
  {
    'id': 'nazca', 'orden': 3,
    'name': {'it': 'Nazca', 'es': 'Nazca', 'en': 'Nazca'},
    'region': {'it': 'Ica, costa meridionale', 'es': 'Ica, costa sur', 'en': 'Ica, southern coast'},
    'period': {'it': 'Geoglifi e deserto rituale', 'es': 'Geoglifos y desierto ritual', 'en': 'Geoglyphs and ritual desert'},
    'image_asset': 'assets/images/banners/caral-desertico.jpg',
    'pos_x': 0.38, 'pos_y': 0.55, 'accent_color': 'FFD8A64A',
  },
  {
    'id': 'moche', 'orden': 4,
    'name': {'it': 'Moche', 'es': 'Moche', 'en': 'Moche'},
    'region': {'it': 'La Libertad, costa nord', 'es': 'La Libertad, costa norte', 'en': 'La Libertad, northern coast'},
    'period': {'it': 'Arte e potere costiero', 'es': 'Arte y poder costero', 'en': 'Coastal art and power'},
    'image_asset': 'assets/images/moche/moche_1.jpg',
    'pos_x': 0.38, 'pos_y': 0.20, 'accent_color': 'FFC1440E',
    'content_item_id': 'moche',
  },
  {
    'id': 'chan_chan', 'orden': 5,
    'name': {'it': 'Chan Chan', 'es': 'Chan Chan', 'en': 'Chan Chan'},
    'region': {'it': 'La Libertad, Trujillo', 'es': 'La Libertad, Trujillo', 'en': 'La Libertad, Trujillo'},
    'period': {'it': 'Capitale Chimu', 'es': 'Capital Chimu', 'en': 'Chimu capital'},
    'image_asset': 'assets/images/moche/moche_3.jpg',
    'pos_x': 0.33, 'pos_y': 0.16, 'accent_color': 'FFB86F35',
  },
  {
    'id': 'machu_picchu', 'orden': 6,
    'name': {'it': 'Machu Picchu', 'es': 'Machu Picchu', 'en': 'Machu Picchu'},
    'region': {'it': 'Cusco, valle dell Urubamba', 'es': 'Cusco, valle del Urubamba', 'en': 'Cusco, Urubamba Valley'},
    'period': {'it': 'Santuario inca', 'es': 'Santuario inca', 'en': 'Inca sanctuary'},
    'image_asset': 'assets/images/banners/machu-picchu-amanecer.jpg',
    'pos_x': 0.60, 'pos_y': 0.63, 'accent_color': 'FFC8860A',
    'content_item_id': 'machu_picchu',
  },
  {
    'id': 'lago_titicaca', 'orden': 7,
    'name': {'it': 'Lago Titicaca', 'es': 'Lago Titicaca', 'en': 'Lake Titicaca'},
    'region': {'it': 'Puno, altopiano', 'es': 'Puno, altiplano', 'en': 'Puno, high plateau'},
    'period': {'it': 'Territorio sacro andino', 'es': 'Territorio sagrado andino', 'en': 'Sacred Andean territory'},
    'image_asset': 'assets/images/tiahuanaco/tiahuanaco_2.jpg',
    'pos_x': 0.70, 'pos_y': 0.76, 'accent_color': 'FF4A7C9E',
    'content_item_id': 'lago_titicaca',
  },
  {
    'id': 'cusco', 'orden': 8,
    'name': {'it': 'Cusco', 'es': 'Cusco', 'en': 'Cusco'},
    'region': {'it': 'Cusco, Ande meridionali', 'es': 'Cusco, Andes del sur', 'en': 'Cusco, southern Andes'},
    'period': {'it': 'Capitale del Tahuantinsuyo', 'es': 'Capital del Tahuantinsuyo', 'en': 'Capital of Tawantinsuyu'},
    'image_asset': 'assets/images/inca/inca_2.jpg',
    'pos_x': 0.58, 'pos_y': 0.58, 'accent_color': 'FFC8860A',
  },
];

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL'];
  final key = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  if (url == null || url.isEmpty || key == null || key.isEmpty) {
    stderr.writeln('✖ Faltan variables de entorno.');
    stderr.writeln('  Define SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY.');
    exitCode = 1;
    return;
  }

  if (!Directory(_dataDir).existsSync()) {
    stderr.writeln('✖ No se encuentra "$_dataDir". '
        'Ejecuta el script desde la raíz del proyecto.');
    exitCode = 1;
    return;
  }

  // Verifica que la clave sea service_role (la que omite el RLS). Si es la
  // clave "anon", el INSERT fallará con 42501; lo avisamos antes de empezar.
  final role = _roleFromJwt(key);
  if (role == 'anon') {
    stderr.writeln('✖ La clave es la "anon", no la "service_role".');
    stderr.writeln('  Copia la service_role: Supabase → Project Settings →');
    stderr.writeln('  API → Project API keys → service_role (secret).');
    exitCode = 1;
    return;
  }
  if (role != null && role != 'service_role') {
    stderr.writeln('⚠ La clave tiene rol "$role" (se esperaba service_role).');
  }

  final seeder = _Seeder(url, key);

  try {
    // ── 1) content_items ──
    final content = <Map<String, dynamic>>[];
    for (final file in _editorialFiles) {
      for (final item in _readList(file)) {
        content.add(_contentRow(item));
      }
    }
    await seeder.upsert('content_items', content);

    // ── 2) historia_stages ──
    final stages = _readList('historia_stages.json').map(_stageRow).toList();
    await seeder.upsert('historia_stages', stages);

    // ── 3) historia_articles ──
    final articles = <Map<String, dynamic>>[];
    _articleFiles.forEach((file, stageId) {
      for (final a in _readList(file)) {
        articles.add(_articleRow(a, stageId));
      }
    });
    await seeder.upsert('historia_articles', articles);

    // ── 4) timeline_items ──
    final timeline = _readList('timeline_items.json').map(_timelineRow).toList();
    await seeder.upsert('timeline_items', timeline);

    // ── 5) map_points ──
    await seeder.upsert('map_points', List.of(_mapPoints));

    stdout.writeln('\n✅ Seed completado correctamente.');
  } catch (e) {
    stderr.writeln('\n✖ Error durante el seed: $e');
    exitCode = 1;
  }
}

// ── Lectura de archivos ──────────────────────────────────────────────────────

/// Devuelve el `role` del payload de un JWT de Supabase (anon/service_role),
/// o `null` si la clave no es un JWT (p. ej. el nuevo formato sb_secret_...).
String? _roleFromJwt(String key) {
  try {
    final parts = key.split('.');
    if (parts.length != 3) return null; // no es JWT
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
    final json = jsonDecode(utf8.decode(base64.decode(payload)));
    return (json as Map<String, dynamic>)['role'] as String?;
  } catch (_) {
    return null;
  }
}

List<Map<String, dynamic>> _readList(String fileName) {
  final raw = File('$_dataDir/$fileName').readAsStringSync();
  final decoded = jsonDecode(raw) as List<dynamic>;
  return decoded.cast<Map<String, dynamic>>();
}

// ── Transformación JSON → fila de tabla ──────────────────────────────────────
// Se eligen explícitamente las columnas para no enviar claves inexistentes.

Map<String, dynamic> _contentRow(Map<String, dynamic> j) => {
      'id': j['id'],
      'category': j['category'],
      'orden': j['orden'] ?? 0,
      'titulo': j['titulo'] ?? {},
      'subtitulo': j['subtitulo'] ?? {},
      'contenido': j['contenido'] ?? {},
      'fuente': j['fuente'],
      'imagen_local': j['imagen_local'],
    };

Map<String, dynamic> _stageRow(Map<String, dynamic> j) => {
      'id': j['id'],
      'orden': j['orden'] ?? 0,
      'accent_color': j['accent_color'],
      'periodo': j['periodo'] ?? {},
      'titulo': j['titulo'] ?? {},
      'subtitulo': j['subtitulo'] ?? {},
    };

Map<String, dynamic> _articleRow(Map<String, dynamic> j, String stageId) => {
      'id': j['id'],
      // El archivo es la fuente de verdad de la etapa padre.
      'parent_stage_id': j['parent_stage_id'] ?? stageId,
      'orden': j['orden'] ?? 0,
      'categoria': j['categoria'] ?? {},
      'titulo': j['titulo'] ?? {},
      'subtitulo': j['subtitulo'] ?? {},
      'contenido': j['contenido'] ?? {},
      'periodo': j['periodo'],
      'imagen_sugerida': j['imagen_sugerida'],
    };

Map<String, dynamic> _timelineRow(Map<String, dynamic> j) => {
      'id': j['id'],
      'orden': j['orden'] ?? 0,
      'color': j['color'],
      'titulo': j['titulo'] ?? {},
      'periodo': j['periodo'] ?? {},
      'image': j['image'],
      'stage_id': j['stage_id'],
    };

// ── Cliente de upsert contra PostgREST ───────────────────────────────────────

class _Seeder {
  final String _url;
  final String _key;
  _Seeder(this._url, this._key);

  /// Garantiza que todas las filas compartan el mismo conjunto de claves
  /// (unión de todas), rellenando con null las que falten en alguna fila.
  List<Map<String, dynamic>> _normalize(List<Map<String, dynamic>> rows) {
    final allKeys = <String>{for (final r in rows) ...r.keys};
    return rows
        .map((r) => {for (final k in allKeys) k: r[k]})
        .toList(growable: false);
  }

  Future<void> upsert(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) {
      stdout.writeln('• $table: 0 filas (omitido)');
      return;
    }
    final uri = Uri.parse('$_url/rest/v1/$table');
    final res = await http.post(
      uri,
      headers: {
        'apikey': _key,
        'Authorization': 'Bearer $_key',
        'Content-Type': 'application/json',
        // Upsert por clave primaria; no devuelve el cuerpo (más rápido).
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      // PostgREST exige el mismo conjunto de claves en todas las filas de una
      // inserción múltiple: normalizamos rellenando las ausentes con null.
      body: jsonEncode(_normalize(rows)),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      stdout.writeln('• $table: ${rows.length} filas ✔');
    } else {
      throw 'Fallo en "$table" (HTTP ${res.statusCode}): ${res.body}';
    }
  }
}
