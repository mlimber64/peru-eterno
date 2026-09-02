import 'package:flutter/material.dart';

import 'content_ref.dart';

class EraModel implements ContentRef {
  @override
  final String id;
  @override
  final bool isPremium;
  final List<String> imageFilenames;
  final Color accentColor;
  final int sortOrder;
  final Map<String, String> wikipediaSlug;

  /// Carpeta de las imágenes cuando NO sigue la convención
  /// `assets/images/<id>/`. Existe por Caral, cuyas ilustraciones viven en
  /// `assets/images/content/caral/` (las usa también [CaralHeroCarousel]):
  /// su carpeta por convención quedó vacía y la tarjeta de la línea de tiempo
  /// se veía como un rectángulo de degradado sin foto.
  final String? imageFolderOverride;

  const EraModel({
    required this.id,
    required this.isPremium,
    required this.imageFilenames,
    required this.accentColor,
    required this.sortOrder,
    required this.wikipediaSlug,
    this.imageFolderOverride,
  });

  /// Las eras son siempre categoría 'era' (usado por la UI genérica que
  /// mezcla eras con [ContentItem] de otras categorías).
  @override
  String get category => 'era';

  String get imageFolderPath => imageFolderOverride ?? 'assets/images/$id/';

  String imageAssetPath(String filename) => '$imageFolderPath$filename';

  @override
  String? slugForLang(String lang) => wikipediaSlug[lang];

  @override
  String localizedTitle(String Function(String) t) {
    final key = 'eras.$id.title';
    final value = t(key);
    return value == key ? id : value;
  }

  @override
  String? localizedSubtitle(String Function(String) t) {
    final key = 'eras.$id.subtitle';
    final value = t(key);
    return value == key ? null : value;
  }
}
