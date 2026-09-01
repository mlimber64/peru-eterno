/// Documentos legales de la app (política de privacidad y términos de
/// servicio), cargados desde `assets/legal/legal.json`.
///
/// Son la MISMA fuente que alimenta las páginas HTML públicas de
/// `docs/` (ver `tool/generate_legal_html.dart`): el texto que ve el usuario
/// dentro de la app y el que exige la ficha de Play Console no pueden
/// divergir, así que ninguno de los dos se escribe a mano por separado.
enum LegalDocType {
  privacy,
  terms;

  /// Clave del documento dentro del JSON.
  String get jsonKey => name;
}

/// Un apartado numerado del documento ("1. Responsable del tratamiento").
class LegalSection {
  final String heading;
  final List<String> paragraphs;

  const LegalSection({required this.heading, required this.paragraphs});

  factory LegalSection.fromJson(Map<String, dynamic> json) {
    final raw = json['p'];
    return LegalSection(
      heading: json['h']?.toString() ?? '',
      paragraphs: raw is List ? raw.map((e) => e.toString()).toList() : const [],
    );
  }
}

/// Un documento legal completo, ya resuelto a un idioma concreto y con los
/// marcadores (`{email}`, `{updated_at}`) sustituidos.
class LegalDocument {
  final LegalDocType type;
  final String title;
  final String intro;
  final List<LegalSection> sections;

  /// Fecha de última actualización (ISO `YYYY-MM-DD`), para el encabezado.
  final String updatedAt;

  /// Email de contacto publicado. Vive en el JSON, no en el código, para
  /// cambiarlo en un solo sitio (app + HTML público a la vez).
  final String contactEmail;

  const LegalDocument({
    required this.type,
    required this.title,
    required this.intro,
    required this.sections,
    required this.updatedAt,
    required this.contactEmail,
  });
}
