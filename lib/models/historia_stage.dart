import 'package:flutter/material.dart';

import '../core/utils/localized_map.dart';

class HistoriaStage {
  final String id;
  final int orden;
  final Map<String, String> titulo;
  final Map<String, String> subtitulo;
  final Map<String, String> periodo;
  final Color accentColor;

  /// Etapa de pago. En la v1.0 solo "Perú prehispánico" es libre: es la puerta
  /// de entrada temática y da 8 capítulos con los que engancharse; las otras
  /// cuatro van al paywall. Viene de `es_premium` en
  /// `assets/data/historia_stages.json`, así que cambiar qué se regala no
  /// toca código.
  final bool isPremium;

  const HistoriaStage({
    required this.id,
    required this.orden,
    required this.titulo,
    required this.subtitulo,
    required this.periodo,
    required this.accentColor,
    this.isPremium = false,
  });

  factory HistoriaStage.fromJson(Map<String, dynamic> json) {
    final colorHex = json['accent_color'] as String;
    final color = Color(int.parse(colorHex, radix: 16));
    return HistoriaStage(
      id: json['id'] as String,
      orden: json['orden'] as int,
      titulo: LocalizedMapX.parse(json['titulo']),
      subtitulo: LocalizedMapX.parse(json['subtitulo']),
      periodo: LocalizedMapX.parse(json['periodo']),
      accentColor: color,
      isPremium: json['es_premium'] as bool? ?? false,
    );
  }

  /// Ruta del asset de imagen de fondo de la etapa (derivada del id).
  String get imageAssetPath => 'assets/images/stages/$id.webp';

  String tituloFor(String lang) => titulo.localizedFor(lang, fallback: id);
  String subtituloFor(String lang) => subtitulo.localizedFor(lang);
  String periodoFor(String lang) => periodo.localizedFor(lang);
}
