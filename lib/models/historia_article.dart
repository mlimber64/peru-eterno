// Modelo para artículos editoriales de Historia preispanica.
// Fuente: assets/data/historia_prehispanica.json
// Independiente del sistema Wikipedia (ErasRepository + WikipediaService).

class HistoriaArticle {
  final String id;
  final Map<String, String> categoria;
  final int orden;
  final Map<String, String> titulo;
  final Map<String, String> subtitulo;
  final String imagenSugerida;
  final Map<String, String> contenido;
  final String? parentStageId;
  final Map<String, String>? periodo;

  const HistoriaArticle({
    required this.id,
    required this.categoria,
    required this.orden,
    required this.titulo,
    required this.subtitulo,
    required this.imagenSugerida,
    required this.contenido,
    this.parentStageId,
    this.periodo,
  });

  factory HistoriaArticle.fromJson(Map<String, dynamic> json) {
    return HistoriaArticle(
      id: json['id'] as String,
      categoria: _toStringMap(json['categoria']),
      orden: json['orden'] as int,
      titulo: _toStringMap(json['titulo']),
      subtitulo: _toStringMap(json['subtitulo']),
      imagenSugerida: json['imagen_sugerida'] as String,
      contenido: _toStringMap(json['contenido']),
      parentStageId: json['parent_stage_id'] as String?,
      periodo: json['periodo'] != null ? _toStringMap(json['periodo']) : null,
    );
  }

  // Getters localizados — fallback a italiano (idioma principal)
  String tituloFor(String lang) => titulo[lang] ?? titulo['it'] ?? id;
  String subtituloFor(String lang) => subtitulo[lang] ?? subtitulo['it'] ?? '';
  String categoriaFor(String lang) => categoria[lang] ?? categoria['it'] ?? '';
  String contenidoFor(String lang) => contenido[lang] ?? contenido['it'] ?? '';
  String? periodoFor(String lang) => periodo?[lang] ?? periodo?['it'];

  // Ruta de imagen local (en assets/images/historia/)
  String get imagenAssetPath => 'assets/images/historia/$imagenSugerida';

  static Map<String, String> _toStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }
}
