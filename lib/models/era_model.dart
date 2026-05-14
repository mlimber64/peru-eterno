import 'package:flutter/material.dart';

class EraModel {
  final String id;
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

  String get imageFolderPath => 'assets/images/$id/';

  String imageAssetPath(String filename) => '$imageFolderPath$filename';

  String? slugForLang(String lang) => wikipediaSlug[lang];
}
