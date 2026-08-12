import '../core/utils/localized_map.dart';

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
      titulo: LocalizedMapX.parse(json['titulo']),
      subtitulo: LocalizedMapX.parse(json['subtitulo']),
      contenido: LocalizedMapX.parse(json['contenido']),
      imagenLocal: json['imagen_local'] as String?,
      fuente: json['fuente'] != null ? LocalizedMapX.parse(json['fuente']) : null,
    );
  }

  // Fallback it → es → en
  String tituloFor(String lang) => titulo.localizedFor(lang, fallback: id);
  String subtituloFor(String lang) => subtitulo.localizedFor(lang);
  String contenidoFor(String lang) => contenido.localizedFor(lang);
  String? fuenteFor(String lang) => fuente?.localizedFor(lang);

  String? get imagenAssetPath =>
      imagenLocal != null ? 'assets/images/content/$imagenLocal' : null;
}
