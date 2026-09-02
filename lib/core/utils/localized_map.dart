/// Utilidades compartidas para los mapas multilenguaje (`Map<String, String>`)
/// usados por el contenido editorial (`{'it': ..., 'es': ..., 'en': ...}`).
extension LocalizedMapX on Map<String, String>? {
  /// Resuelve el texto en [lang] con cascada de fallback
  /// `lang -> 'it' -> 'es' -> 'en' -> [fallback]`.
  String localizedFor(String lang, {String fallback = ''}) {
    final map = this;
    if (map == null) return fallback;
    return map[lang] ?? map['it'] ?? map['es'] ?? map['en'] ?? fallback;
  }

  /// Parsea de forma segura un `Map` dinámico (típicamente decodificado de
  /// JSON) a `Map<String, String>`. Devuelve un mapa vacío si [raw] no es
  /// un `Map`.
  static Map<String, String> parse(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }
}
