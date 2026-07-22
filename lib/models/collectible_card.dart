import 'package:flutter/material.dart';

/// Rareza de una tarjeta coleccionable. El orden de los valores es también
/// el orden de "valor" ascendente (usado para ordenar y para el brillo).
enum CardRarity { comun, rara, epica, legendaria }

extension CardRarityX on CardRarity {
  static CardRarity fromString(String raw) => CardRarity.values.firstWhere(
        (r) => r.name == raw,
        orElse: () => CardRarity.comun,
      );

  /// Color distintivo de la rareza (borde/brillo en el álbum).
  Color get color => switch (this) {
        CardRarity.comun => const Color(0xFF9CA3AF),
        CardRarity.rara => const Color(0xFF4A9BD8),
        CardRarity.epica => const Color(0xFFA855D6),
        CardRarity.legendaria => const Color(0xFFFFC24B),
      };

  String labelKey() => switch (this) {
        CardRarity.comun => 'collectibles.rarity_common',
        CardRarity.rara => 'collectibles.rarity_rare',
        CardRarity.epica => 'collectibles.rarity_epic',
        CardRarity.legendaria => 'collectibles.rarity_legendary',
      };
}

/// Tarjeta coleccionable de un capítulo. Título, imagen y descripción se
/// obtienen del [HistoriaArticle] correspondiente (mismo `id`); este modelo
/// añade el diseño de juego (rareza) y el estado de desbloqueo del usuario.
class CollectibleCard {
  final String id;
  final String stageId;
  final CardRarity rarity;
  final Map<String, String> titulo;
  final String imagen;
  final Map<String, String> descripcion;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const CollectibleCard({
    required this.id,
    required this.stageId,
    required this.rarity,
    required this.titulo,
    required this.imagen,
    required this.descripcion,
    required this.isUnlocked,
    this.unlockedAt,
  });

  String tituloFor(String lang) => titulo[lang] ?? titulo['it'] ?? id;
  String descripcionFor(String lang) =>
      descripcion[lang] ?? descripcion['it'] ?? '';

  CollectibleCard copyWith({bool? isUnlocked, DateTime? unlockedAt}) =>
      CollectibleCard(
        id: id,
        stageId: stageId,
        rarity: rarity,
        titulo: titulo,
        imagen: imagen,
        descripcion: descripcion,
        isUnlocked: isUnlocked ?? this.isUnlocked,
        unlockedAt: unlockedAt ?? this.unlockedAt,
      );
}
