import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/legal_document.dart';

/// Carga los documentos legales de `assets/legal/legal.json`.
///
/// El JSON está cacheado en memoria: se lee una sola vez por sesión aunque
/// el usuario abra privacidad y términos, o cambie de idioma.
class LegalRepository {
  LegalRepository._();
  static final LegalRepository instance = LegalRepository._();

  static const String assetPath = 'assets/legal/legal.json';

  Map<String, dynamic>? _cache;

  Future<Map<String, dynamic>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _cache = decoded;
    return decoded;
  }

  /// Devuelve [type] en [lang], con la misma cascada de fallback que el resto
  /// del contenido (`lang -> it -> es -> en`), ver `LocalizedMapX`.
  ///
  /// Sustituye los marcadores `{email}` y `{updated_at}` por los valores
  /// globales del JSON, para que el email de contacto se cambie en un único
  /// sitio en vez de repetido en 6 documentos.
  Future<LegalDocument> load(LegalDocType type, String lang) async {
    final json = await _load();
    final email = json['contact_email']?.toString() ?? '';
    final updatedAt = json['updated_at']?.toString() ?? '';

    final byLang = json[type.jsonKey] as Map<String, dynamic>? ?? const {};
    final doc = (byLang[lang] ??
        byLang['it'] ??
        byLang['es'] ??
        byLang['en']) as Map<String, dynamic>?;

    if (doc == null) {
      throw StateError('Documento legal "${type.jsonKey}" ausente en $assetPath');
    }

    String fill(String value) => value
        .replaceAll('{email}', email)
        .replaceAll('{updated_at}', updatedAt);

    final rawSections = doc['sections'];
    return LegalDocument(
      type: type,
      title: fill(doc['title']?.toString() ?? ''),
      intro: fill(doc['intro']?.toString() ?? ''),
      sections: rawSections is List
          ? rawSections
              .whereType<Map<String, dynamic>>()
              .map(LegalSection.fromJson)
              .map((s) => LegalSection(
                    heading: fill(s.heading),
                    paragraphs: s.paragraphs.map(fill).toList(),
                  ))
              .toList()
          : const [],
      updatedAt: updatedAt,
      contactEmail: email,
    );
  }
}
