class EuropeanaItem {
  final String id;
  final String title;
  final String institution;
  final String? thumbnailUrl;
  final String? fullImageUrl;
  final String europeanaUrl;

  const EuropeanaItem({
    required this.id,
    required this.title,
    required this.institution,
    this.thumbnailUrl,
    this.fullImageUrl,
    required this.europeanaUrl,
  });

  bool get hasImage => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;
}
