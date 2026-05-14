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
  // Actual language used — may differ from user's language when fallback was triggered
  final String displayLang;

  const WikipediaContent({
    required this.title,
    required this.sections,
    this.thumbnailUrl,
    required this.sourceUrl,
    required this.cachedAt,
    this.displayLang = '',
  });

  // Backward-compat: text of lead section
  String get extract =>
      sections.isNotEmpty ? sections.first.content : '';

  bool get hasContent => sections.any((s) => s.content.length > 30);
  bool get hasThumbnail => thumbnailUrl != null && thumbnailUrl!.isNotEmpty;

  int get totalContentChars =>
      sections.fold(0, (sum, s) => sum + s.content.length);

  List<WikipediaSection> get contentSections =>
      sections.where((s) => !s.isLead).toList();
  WikipediaSection? get leadSection =>
      sections.where((s) => s.isLead).firstOrNull;

  // ── Parsing ──────────────────────────────────────────────────────────────

  static const Set<String> _skipTitles = {
    // ES
    'referencias', 'véase también', 'bibliografía', 'notas',
    'fuentes', 'enlaces externos', 'galería', 'galeria',
    'lectura adicional', 'notas y referencias', 'notas al pie', 'citas',
    'en otros idiomas', 'publicaciones', 'obras',
    // EN
    'references', 'see also', 'bibliography', 'notes',
    'external links', 'gallery', 'further reading', 'sources',
    'footnotes', 'citations', 'other languages',
    // IT
    'riferimenti', 'vedi anche', 'bibliografia', 'note',
    'fonti', 'collegamenti esterni', 'galleria',
    'letture consigliate', 'altre lingue',
  };

  static List<WikipediaSection> parseSections(String fullText) {
    final sections = <WikipediaSection>[];
    final lines = fullText.split('\n');
    final headerRe = RegExp(r'^(={2,4})\s*(.+?)\s*\1\s*$');

    String currentTitle = '';
    int currentLevel = 0;
    final buffer = StringBuffer();

    void flush() {
      final content = buffer.toString().trim();
      buffer.clear();
      if (content.length < 40) return;
      if (_skipTitles.contains(currentTitle.toLowerCase().trim())) return;
      sections.add(WikipediaSection(
        title: currentTitle,
        content: content,
        level: currentLevel,
      ));
    }

    for (final line in lines) {
      final match = headerRe.firstMatch(line.trim());
      if (match != null) {
        flush();
        currentTitle = match.group(2) ?? '';
        currentLevel = (match.group(1)?.length ?? 2) - 1;
      } else {
        if (buffer.isNotEmpty || line.trim().isNotEmpty) {
          buffer.writeln(line);
        }
      }
    }
    flush();

    return sections;
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  factory WikipediaContent.fromApiResponse({
    required Map<String, dynamic> pageJson,
    required String lang,
    required String slug,
  }) {
    final rawExtract = pageJson['extract'] as String? ?? '';
    final thumbnail = pageJson['thumbnail'] as Map<String, dynamic>?;
    final title = pageJson['title'] as String? ?? slug;
    final pageId = pageJson['pageid'];

    final sourceUrl = pageId != null
        ? 'https://$lang.wikipedia.org/wiki/${Uri.encodeComponent(title)}'
        : 'https://$lang.wikipedia.org/wiki/${Uri.encodeComponent(slug)}';

    return WikipediaContent(
      title: title,
      sections: parseSections(rawExtract),
      thumbnailUrl: thumbnail?['source'] as String?,
      sourceUrl: sourceUrl,
      cachedAt: DateTime.now(),
      displayLang: lang,
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
      // Migrate from old cache format (single extract string)
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
    );
  }

  Map<String, dynamic> toCache() => {
        'title': title,
        'sections': sections.map((s) => s.toJson()).toList(),
        'thumbnailUrl': thumbnailUrl,
        'sourceUrl': sourceUrl,
        'cachedAt': cachedAt.toIso8601String(),
        'displayLang': displayLang,
        'version': 2,
      };

  String toCacheString() => jsonEncode(toCache());
}
