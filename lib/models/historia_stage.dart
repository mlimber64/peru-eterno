import 'package:flutter/material.dart';

class HistoriaStage {
  final String id;
  final int orden;
  final Map<String, String> titulo;
  final Map<String, String> subtitulo;
  final Map<String, String> periodo;
  final Color accentColor;

  const HistoriaStage({
    required this.id,
    required this.orden,
    required this.titulo,
    required this.subtitulo,
    required this.periodo,
    required this.accentColor,
  });

  factory HistoriaStage.fromJson(Map<String, dynamic> json) {
    final colorHex = json['accent_color'] as String;
    final color = Color(int.parse(colorHex, radix: 16));
    return HistoriaStage(
      id: json['id'] as String,
      orden: json['orden'] as int,
      titulo: _toStringMap(json['titulo']),
      subtitulo: _toStringMap(json['subtitulo']),
      periodo: _toStringMap(json['periodo']),
      accentColor: color,
    );
  }

  /// Ruta del asset de imagen de fondo de la etapa (derivada del id).
  String get imageAssetPath => 'assets/images/stages/$id.webp';

  String tituloFor(String lang) => titulo[lang] ?? titulo['it'] ?? id;
  String subtituloFor(String lang) => subtitulo[lang] ?? subtitulo['it'] ?? '';
  String periodoFor(String lang) => periodo[lang] ?? periodo['it'] ?? '';

  static Map<String, String> _toStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }
}
