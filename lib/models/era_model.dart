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

  const EraModel({
    required this.id,
    required this.isPremium,
    required this.imageFilenames,
    required this.accentColor,
    required this.sortOrder,
    required this.wikipediaSlug,
  });

  /// Las eras son siempre categoría 'era' (usado por la UI genérica que
  /// mezcla eras con [ContentItem] de otras categorías).
  @override
  String get category => 'era';

  String get imageFolderPath => 'assets/images/$id/';

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
