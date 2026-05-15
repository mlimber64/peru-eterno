import 'package:flutter/material.dart';

class TimelineItem {
  final String id;
  final int orden;
  final Color color;
  final Map<String, String> titulo;
  final Map<String, String> periodo;
  final String? imagePath;
  final String? stageId;

  const TimelineItem({
    required this.id,
    required this.orden,
    required this.color,
    required this.titulo,
    required this.periodo,
    this.imagePath,
    this.stageId,
  });

  factory TimelineItem.fromJson(Map<String, dynamic> json) {
    final colorHex = json['color'] as String;
    return TimelineItem(
      id: json['id'] as String,
      orden: json['orden'] as int,
      color: Color(int.parse(colorHex, radix: 16)),
      titulo: Map<String, String>.from(json['titulo'] as Map),
      periodo: Map<String, String>.from(json['periodo'] as Map),
      imagePath: json['image'] as String?,
      stageId: json['stage_id'] as String?,
    );
  }

  String tituloFor(String lang) => titulo[lang] ?? titulo['it'] ?? id;
  String periodoFor(String lang) => periodo[lang] ?? periodo['it'] ?? '';
}
