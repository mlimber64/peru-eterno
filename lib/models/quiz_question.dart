/// Pregunta de opción múltiple asociada a un [HistoriaArticle] (capítulo).
/// Fuente: campo `quiz` de los archivos en `assets/data-refactor/`.
class QuizQuestion {
  final Map<String, String> pregunta;
  final Map<String, List<String>> opciones;
  final int respuestaCorrecta;
  final Map<String, String> explicacion;

  const QuizQuestion({
    required this.pregunta,
    required this.opciones,
    required this.respuestaCorrecta,
    required this.explicacion,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final opcionesRaw = json['opciones'] as Map<String, dynamic>;
    return QuizQuestion(
      pregunta: _toStringMap(json['pregunta']),
      opciones: opcionesRaw.map(
        (lang, list) => MapEntry(
          lang,
          (list as List).map((e) => e.toString()).toList(),
        ),
      ),
      respuestaCorrecta: json['respuesta_correcta'] as int,
      explicacion: _toStringMap(json['explicacion']),
    );
  }

  String preguntaFor(String lang) => pregunta[lang] ?? pregunta['it'] ?? '';
  List<String> opcionesFor(String lang) =>
      opciones[lang] ?? opciones['it'] ?? const [];
  String explicacionFor(String lang) =>
      explicacion[lang] ?? explicacion['it'] ?? '';

  static Map<String, String> _toStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }
}
