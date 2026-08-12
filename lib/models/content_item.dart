import 'content_ref.dart';

class ContentItem implements ContentRef {
  @override
  final String id;
  @override
  final String
      category; // era | personaje | tradicion | gastronomia | musica | geografia
  final Map<String, String> wikipediaSlug;
  @override
  final bool isPremium;

  const ContentItem({
    required this.id,
    required this.category,
    required this.wikipediaSlug,
    this.isPremium = false,
  });

  @override
  String? slugForLang(String lang) => wikipediaSlug[lang];

  /// Human-readable name derived from the Spanish Wikipedia slug.
  String get displayName {
    final slug = wikipediaSlug['es'] ?? id;
    return slug
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'\s*\(.*?\)\s*'), '')
        .trim();
  }

  @override
  String localizedTitle(String Function(String) t) {
    final key = 'content.items.$id.title';
    final value = t(key);
    return value == key ? displayName : value;
  }

  @override
  String? localizedSubtitle(String Function(String) t) {
    final key = 'content.items.$id.subtitle';
    final value = t(key);
    return value == key ? null : value;
  }
}
