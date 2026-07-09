import 'dart:convert';

class WikipediaSection {
  final String title;
  final String content;
  final int level;

  const WikipediaSection({
    required this.title,
    required this.content,
    required this.level,
  });

  bool get isLead => title.isEmpty;

  factory WikipediaSection.fromJson(Map<String, dynamic> json) {
    return WikipediaSection(
      title: json['title'] as String,
      content: json['content'] as String,
      level: json['level'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'level': level,
      };
}

class WikipediaContent {
  final String title;
  final List<WikipediaSection> sections;
  final String? thumbnailUrl;
  final String sourceUrl;
  final DateTime cachedAt;
  final String displayLang;
  // True when content was served from local cache, not freshly fetched
  final bool isFromCache;

  const WikipediaContent({
    required this.title,
    required this.sections,
    this.thumbnailUrl,
    required this.sourceUrl,
    required this.cachedAt,
    this.displayLang = '',
    this.isFromCache = false,
  });

  String get extract => sections.isNotEmpty ? sections.first.content : '';

  bool get hasContent => sections.any((s) => s.content.length > 30);
  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;

  int get totalContentChars =>
      sections.fold(0, (sum, s) => sum + s.content.length);

  List<WikipediaSection> get contentSections =>
      sections.where((s) => !s.isLead).toList();
  WikipediaSection? get leadSection =>
      sections.where((s) => s.isLead).firstOrNull;

  // ── Text cleaning ──────────────────────────────────────────────────────────

  static String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')      // collapse 3+ newlines
        .replaceAll(RegExp(r'[^\S\n]+\n'), '\n')     // trailing spaces on lines
        .replaceAll(RegExp(r'={2,}[^=\n]*={2,}'), '') // leftover == headers ==
        .replaceAll(RegExp(r'\[\d+\]'), '')           // citation numbers [1]
        .replaceAll(' ', ' ')                    // non-breaking space
        .replaceAll('\t', ' ')                        // tabs → space
        .trim();
  }

  // ── Section parsing ───────────────────────────────────────────────────────
  //
  // Splits `exsectionformat=plain` extract by double newlines.
  // First chunk → lead section (no title).
  // Subsequent chunks: if first line is short & looks like a header, it
  // becomes the section title; the rest is the body.
  // Limits: max 8 sections, max 800 chars per section body.

  static const int _maxSections = 8;
  static const int _maxChars = 800;

  static const Set<String> _skipTitles = {
    // ES
    'referencias', 'véase también', 'bibliografía', 'notas',
    'fuentes', 'enlaces externos', 'galería', 'galeria',
    'lectura adicional', 'notas y referencias', 'notas al pie', 'citas',
    'publicaciones', 'obras', 'en la cultura popular', 'filmografía',
    // EN
    'references', 'see also', 'bibliography', 'notes',
    'external links', 'gallery', 'further reading', 'sources',
    'footnotes', 'citations', 'in popular culture', 'filmography',
    // IT
    'riferimenti', 'vedi anche', 'note', 'fonti',
    'collegamenti esterni', 'galleria', 'letture consigliate',
    'nella cultura di massa', 'filmografia',
  };

  static List<WikipediaSection> parseSections(String fullText) {
    final cleaned = _cleanText(fullText);
    if (cleaned.isEmpty) return [];

    final chunks = cleaned.split('\n\n');
    final sections = <WikipediaSection>[];
    bool isFirst = true;

    for (final chunk in chunks) {
      final trimmed = chunk.trim();
      if (trimmed.length < 40) continue;

      String sectionTitle = '';
      String sectionBody = trimmed;

      // For non-lead chunks, detect if the first line is a section header:
      // short (≤ 70 chars), no terminal punctuation, followed by body text.
      if (!isFirst) {
        final lines = trimmed
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (lines.length >= 2) {
          final firstLine = lines.first;
          if (firstLine.length <= 70 &&
              !firstLine.endsWith('.') &&
              !firstLine.endsWith(',') &&
              !firstLine.endsWith(';') &&
              !firstLine.endsWith(':')) {
            sectionTitle = firstLine;
            sectionBody = lines.skip(1).join('\n').trim();
          }
        }
      }

      if (sectionBody.length < 40) continue;
      if (_skipTitles.contains(sectionTitle.toLowerCase().trim())) continue;

      final truncated = sectionBody.length > _maxChars
          ? sectionBody.substring(0, _maxChars).trimRight()
          : sectionBody;

      sections.add(WikipediaSection(
        title: isFirst ? '' : sectionTitle,
        content: truncated,
        level: sectionTitle.isEmpty ? 0 : 1,
      ));

      isFirst = false;
      if (sections.length >= _maxSections) break;
    }

    return sections;
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  factory WikipediaContent.fromApiResponse({
    required Map<String, dynamic> pageJson,
    required String lang,
    required String slug,
    String? thumbnailUrl,
  }) {
    final rawExtract = pageJson['extract'] as String? ?? '';
    final title = pageJson['title'] as String? ?? slug;
    final pageId = pageJson['pageid'];

    final sourceUrl = pageId != null
        ? 'https://$lang.wikipedia.org/wiki/${Uri.encodeComponent(title)}'
        : 'https://$lang.wikipedia.org/wiki/${Uri.encodeComponent(slug)}';

    return WikipediaContent(
      title: title,
      sections: parseSections(rawExtract),
      thumbnailUrl: thumbnailUrl,
      sourceUrl: sourceUrl,
      cachedAt: DateTime.now(),
      displayLang: lang,
      isFromCache: false,
    );
  }

  factory WikipediaContent.fromCache(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>?;
    List<WikipediaSection> sections;

    if (rawSections != null) {
      sections = rawSections
          .map((e) => WikipediaSection.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      final oldExtract = json['extract'] as String? ?? '';
      sections = parseSections(oldExtract);
    }

    return WikipediaContent(
      title: json['title'] as String? ?? '',
      sections: sections,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      sourceUrl: json['sourceUrl'] as String? ?? '',
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      displayLang: json['displayLang'] as String? ?? '',
      isFromCache: true,
    );
  }

  WikipediaContent copyWith({String? displayLang, bool? isFromCache}) {
    return WikipediaContent(
      title: title,
      sections: sections,
      thumbnailUrl: thumbnailUrl,
      sourceUrl: sourceUrl,
      cachedAt: cachedAt,
      displayLang: displayLang ?? this.displayLang,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

  Map<String, dynamic> toCache() => {
        'title': title,
        'sections': sections.map((s) => s.toJson()).toList(),
        'thumbnailUrl': thumbnailUrl,
        'sourceUrl': sourceUrl,
        'cachedAt': cachedAt.toIso8601String(),
        'displayLang': displayLang,
        'version': 4,
      };

  String toCacheString() => jsonEncode(toCache());
}
