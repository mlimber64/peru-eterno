class EditorialContent {
  final String id;
  final String category;
  final int orden;
  final Map<String, String> titulo;
  final Map<String, String> subtitulo;
  final Map<String, String> contenido;
  final String? imagenLocal;
  final Map<String, String>? fuente;

  const EditorialContent({
    required this.id,
    required this.category,
    required this.orden,
    required this.titulo,
    required this.subtitulo,
    required this.contenido,
    this.imagenLocal,
    this.fuente,
  });

  factory EditorialContent.fromJson(Map<String, dynamic> json) {
    return EditorialContent(
      id: json['id'] as String,
      category: json['category'] as String,
      orden: json['orden'] as int,
      titulo: _toStringMap(json['titulo']),
      subtitulo: _toStringMap(json['subtitulo']),
      contenido: _toStringMap(json['contenido']),
      imagenLocal: json['imagen_local'] as String?,
      fuente: json['fuente'] != null ? _toStringMap(json['fuente']) : null,
    );
  }

  // Fallback it → es → en
  String tituloFor(String lang) => titulo[lang] ?? titulo['it'] ?? id;
  String subtituloFor(String lang) => subtitulo[lang] ?? subtitulo['it'] ?? '';
  String contenidoFor(String lang) => contenido[lang] ?? contenido['it'] ?? '';
  String? fuenteFor(String lang) => fuente?[lang] ?? fuente?['it'];

  String? get imagenAssetPath =>
      imagenLocal != null ? 'assets/images/content/$imagenLocal' : null;

  static Map<String, String> _toStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }
}
