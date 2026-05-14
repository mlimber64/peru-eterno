import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wikipedia_content.dart';

class WikipediaService {
  static final WikipediaService _instance = WikipediaService._();
  static WikipediaService get instance => _instance;
  WikipediaService._();

  static const Duration _cacheDuration = Duration(days: 7);
  static const Duration _requestTimeout = Duration(seconds: 15);

  // Minimum total chars across all sections to consider content "sufficient"
  static const int _minContentChars = 500;

  // Fallback chain: if the requested language is thin, try these in order
  static const Map<String, List<String>> _fallbacks = {
    'it': ['es', 'en'],
    'es': ['en'],
    'en': [],
  };

  // v2 prefix avoids collisions with old summary-based cache
  String _cacheKey(String eraId, String lang) => 'wiki_v2_${eraId}_$lang';

  bool _isSufficient(WikipediaContent content) =>
      content.hasContent && content.totalContentChars >= _minContentChars;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Fetches Wikipedia content for [eraId] in [lang], falling back to richer
  /// languages if the requested language article is absent or too thin.
  /// [slugMap] must map language codes to Wikipedia article titles.
  Future<WikipediaContent?> fetch({
    required String eraId,
    required String lang,
    required Map<String, String> slugMap,
  }) async {
    // Try cache for the requested language first — only if content is sufficient
    final key = _cacheKey(eraId, lang);
    final cached = await _getFromCache(key);
    if (cached != null && _isSufficient(cached)) return cached;

    // Try fetching the requested language from the API
    final slug = slugMap[lang];
    if (slug != null) {
      final content = await _fetchFromApi(
        eraId: eraId,
        lang: lang,
        slug: slug,
        cacheKey: key,
      );
      if (content != null && _isSufficient(content)) return content;
    }

    // Fallback: try richer languages in order
    for (final fbLang in (_fallbacks[lang] ?? [])) {
      final fbSlug = slugMap[fbLang];
      if (fbSlug == null) continue;

      final fbKey = _cacheKey(eraId, fbLang);

      // Reuse cached fallback if available
      WikipediaContent? fbContent = await _getFromCache(fbKey);
      fbContent ??= await _fetchFromApi(
        eraId: eraId,
        lang: fbLang,
        slug: fbSlug,
        cacheKey: fbKey,
      );

      if (fbContent != null && _isSufficient(fbContent)) {
        // Tag with the actual display language so the UI can show a note
        final tagged = WikipediaContent(
          title: fbContent.title,
          sections: fbContent.sections,
          thumbnailUrl: fbContent.thumbnailUrl,
          sourceUrl: fbContent.sourceUrl,
          cachedAt: fbContent.cachedAt,
          displayLang: fbLang,
        );
        // Cache under the original key so subsequent loads are instant
        await _saveToCache(key, tagged);
        return tagged;
      }
    }

    return null;
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final toRemove = prefs.getKeys()
        .where((k) => k.startsWith('wiki_'))
        .toList();
    for (final k in toRemove) {
      await prefs.remove(k);
    }
  }

  // ── Cache ─────────────────────────────────────────────────────────────────

  Future<WikipediaContent?> _getFromCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;

      // Reject old format (no 'version' field means old summary cache)
      if ((json['version'] as int?) != 2) {
        await prefs.remove(key);
        return null;
      }

      final content = WikipediaContent.fromCache(json);
      if (DateTime.now().difference(content.cachedAt) > _cacheDuration) {
        await prefs.remove(key);
        return null;
      }
      return content;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToCache(String key, WikipediaContent content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, content.toCacheString());
    } catch (_) {}
  }

  // ── Wikipedia Action API ──────────────────────────────────────────────────
  //
  // Uses w/api.php with prop=extracts|pageimages to get the full article
  // text (plain text, with == Section == headers) plus the page thumbnail
  // in a single request.

  Future<WikipediaContent?> _fetchFromApi({
    required String eraId,
    required String lang,
    required String slug,
    required String cacheKey,
  }) async {
    try {
      final url = Uri.https(
        '$lang.wikipedia.org',
        '/w/api.php',
        {
          'action': 'query',
          'titles': slug,
          'prop': 'extracts|pageimages',
          'exintro': 'false',       // full article, not only intro
          'explaintext': 'true',    // plain text, no HTML
          'exsectionformat': 'wiki', // == headers for section detection
          'pithumbsize': '640',     // thumbnail width in px
          'format': 'json',
          'utf8': '1',
          'redirects': '1',         // follow redirects automatically
        },
      );

      final response = await http
          .get(url, headers: {
            'Accept': 'application/json',
            'User-Agent': 'PeruEterno/2.0 (flutter; educational)',
          })
          .timeout(_requestTimeout);

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final pages =
          (body['query'] as Map<String, dynamic>?)?['pages']
              as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) return null;

      // The API returns a map keyed by page ID; -1 means "not found"
      final pageJson = pages.values.first as Map<String, dynamic>;
      if (pageJson['pageid'] == null) return null;

      final content = WikipediaContent.fromApiResponse(
        pageJson: pageJson,
        lang: lang,
        slug: slug,
      );

      if (!content.hasContent) return null;

      await _saveToCache(cacheKey, content);
      return content;
    } catch (_) {
      return null;
    }
  }
}
