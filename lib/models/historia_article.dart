// Modelo para artículos editoriales de Historia preispanica.
// Fuente: assets/data/historia_prehispanica.json
// Independiente del sistema Wikipedia (ErasRepository + WikipediaService).

import '../core/utils/localized_map.dart';
import 'quiz_question.dart';

/// Bloque de curiosidad "¿Sabías qué?" / "Curiosità" / "Fun fact" extraído
/// del contenido de un [HistoriaArticle] (marcado como `**[...]**`).
class ArticleCallout {
  final String header;
  final String body;

  const ArticleCallout({required this.header, required this.body});
}

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
  final List<QuizQuestion> quiz;

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
    this.quiz = const [],
  });

  factory HistoriaArticle.fromJson(Map<String, dynamic> json) {
    return HistoriaArticle(
      id: json['id'] as String,
      categoria: LocalizedMapX.parse(json['categoria']),
      orden: json['orden'] as int,
      titulo: LocalizedMapX.parse(json['titulo']),
      subtitulo: LocalizedMapX.parse(json['subtitulo']),
      imagenSugerida: json['imagen_sugerida'] as String,
      contenido: LocalizedMapX.parse(json['contenido']),
      parentStageId: json['parent_stage_id'] as String?,
      periodo:
          json['periodo'] != null ? LocalizedMapX.parse(json['periodo']) : null,
      quiz: (json['quiz'] as List<dynamic>? ?? const [])
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // Getters localizados — fallback a italiano (idioma principal)
  String tituloFor(String lang) => titulo.localizedFor(lang, fallback: id);
  String subtituloFor(String lang) => subtitulo.localizedFor(lang);
  String categoriaFor(String lang) => categoria.localizedFor(lang);
  String contenidoFor(String lang) => contenido.localizedFor(lang);
  String? periodoFor(String lang) => periodo?.localizedFor(lang);

  /// Párrafos del contenido en [lang] (separados por línea en blanco).
  List<String> _paragraphsFor(String lang) => contenidoFor(lang)
      .split('\n\n')
      .where((p) => p.trim().isNotEmpty)
      .toList();

  /// ¿Es un párrafo la línea final de créditos/fuentes (marcada en el
  /// contenido con cursiva simple `*...*`, a diferencia de la negrita `**`
  /// usada por el resto del texto y por el callout de curiosidad)?
  static bool _isCreditsParagraph(String paragraph) {
    final t = paragraph.trim();
    return t.startsWith('*') && !t.startsWith('**') && t.endsWith('*');
  }

  /// Bloque de curiosidad "¿Sabías qué?" del contenido en [lang], si existe.
  ArticleCallout? calloutFor(String lang) {
    for (final p in _paragraphsFor(lang)) {
      final trimmed = p.trim();
      if (!trimmed.startsWith('**[')) continue;
      final match =
          RegExp(r'^\*\*\[(.+?)\]\*\*', dotAll: true).firstMatch(trimmed);
      if (match == null) continue;
      return ArticleCallout(
        header: match.group(1)!.trim(),
        body: trimmed.substring(match.end).trim(),
      );
    }
    return null;
  }

  /// Línea final de créditos de investigación/fuentes del contenido en
  /// [lang], sin el markdown de cursiva. `null` si el artículo no la trae.
  String? creditosFor(String lang) {
    final paragraphs = _paragraphsFor(lang);
    for (final p in paragraphs.reversed) {
      if (_isCreditsParagraph(p)) {
        final t = p.trim();
        return t.substring(1, t.length - 1).trim();
      }
    }
    return null;
  }

  /// Párrafos "de lectura" del contenido en [lang]: sin el callout de
  /// curiosidad ni la línea de créditos (ambos se muestran en bloques propios
  /// — ver [calloutFor] y [creditosFor]).
  List<String> bodyParagraphsFor(String lang) => _paragraphsFor(lang)
      .where((p) => !p.trim().startsWith('**[') && !_isCreditsParagraph(p))
      .toList();

  /// Tiempo estimado de lectura en minutos (≈200 palabras/minuto), mínimo 1.
  int estimatedReadTimeMinutes(String lang) {
    final wordCount = contenidoFor(lang)
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (wordCount == 0) return 1;
    return (wordCount / 200).ceil().clamp(1, 999);
  }

  // Ruta de imagen local. Los datos enriquecidos (assets/data-refactor/) ya
  // traen la ruta completa (p. ej. "assets/images/caral/caral_1.jpg"); los
  // datos antiguos solo el nombre de archivo dentro de assets/images/historia/.
  String get imagenAssetPath => imagenSugerida.startsWith('assets/')
      ? imagenSugerida
      : 'assets/images/historia/$imagenSugerida';
}
