import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wikipedia_content.dart';

class WikipediaService {
  static final WikipediaService _instance = WikipediaService._();
  static WikipediaService get instance => _instance;
  WikipediaService._();

  static const Duration _cacheDuration = Duration(days: 30);
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const int _minContentChars = 200;

  static const Map<String, List<String>> _fallbacks = {
    'it': ['es', 'en'],
    'es': ['en'],
    'en': [],
  };

  // v4: fixed fallback caching bug (Spanish saved under Italian key)
  String _cacheKey(String contentId, String lang) =>
      'wiki_v4_${contentId}_$lang';

  bool _isSufficient(WikipediaContent c) =>
      c.hasContent && c.totalContentChars >= _minContentChars;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Fetches Wikipedia content for [contentId] in [lang], falling back to
  /// richer languages if needed. [slugMap] maps lang codes → article titles.
  Future<WikipediaContent?> fetch({
    required String contentId,
    required String lang,
    required Map<String, String> slugMap,
  }) async {
    final key = _cacheKey(contentId, lang);
    final cached = await _getFromCache(key);
    if (cached != null && _isSufficient(cached)) return cached;

    final slug = slugMap[lang];
    if (slug != null) {
      final content = await _fetchFromApi(
        contentId: contentId,
        lang: lang,
        slug: slug,
        cacheKey: key,
      );
      if (content != null && _isSufficient(content)) return content;
    }

    for (final fbLang in (_fallbacks[lang] ?? [])) {
      final fbSlug = slugMap[fbLang];
      if (fbSlug == null) continue;

      final fbKey = _cacheKey(contentId, fbLang);
      WikipediaContent? fbContent = await _getFromCache(fbKey);
      fbContent ??= await _fetchFromApi(
        contentId: contentId,
        lang: fbLang,
        slug: fbSlug,
        cacheKey: fbKey,
      );

      if (fbContent != null && _isSufficient(fbContent)) {
        // Return fallback content but do NOT cache it under the requesting
        // language's key — doing so would permanently serve the wrong language.
        // The fallback content is already cached under its own fbKey.
        return fbContent.copyWith(displayLang: fbLang, isFromCache: false);
      }
    }

    // Return stale cache as last resort (offline scenario)
    return cached;
  }

  /// Fetches only the thumbnail URL for a content item, using a lightweight
  /// per-item cache so cards don't re-fetch on every build.
  Future<String?> fetchThumbnailOnly({
    required String contentId,
    required String lang,
    required Map<String, String> slugMap,
  }) async {
    // If full content already cached, reuse its thumbnail
    final fullCached = await _getFromCache(_cacheKey(contentId, lang));
    if (fullCached?.thumbnailUrl != null) return fullCached!.thumbnailUrl;

    // Lightweight URL-only cache
    const thumbVersion = 'v1';
    final thumbKey = 'thumb_${thumbVersion}_${contentId}_$lang';
    final prefs = await SharedPreferences.getInstance();
    final cachedUrl = prefs.getString(thumbKey);
    if (cachedUrl != null) return cachedUrl.isEmpty ? null : cachedUrl;

    // Try preferred lang → es → en
    final tryLangs = [lang, 'es', 'en']
        .where((l) => slugMap.containsKey(l))
        .toList();

    for (final tryLang in tryLangs) {
      final slug = slugMap[tryLang];
      if (slug == null) continue;
      final url = await _fetchThumbnail(tryLang, slug);
      if (url != null) {
        await prefs.setString(thumbKey, url);
        return url;
      }
    }

    await prefs.setString(thumbKey, ''); // cache miss to avoid retries
    return null;
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final toRemove = prefs.getKeys().where((k) => k.startsWith('wiki_')).toList();
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
      if ((json['version'] as int?) != 4) {
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

  // ── Wikipedia Action API — extract ────────────────────────────────────────
  //
  // Uses exsectionformat=plain so section text is clean paragraphs separated
  // by \n\n. WikipediaContent.parseSections handles the splitting.

  Future<WikipediaContent?> _fetchFromApi({
    required String contentId,
    required String lang,
    required String slug,
    required String cacheKey,
  }) async {
    try {
      // Fetch extract and thumbnail in parallel
      final results = await Future.wait([
        _fetchExtract(lang, slug),
        _fetchThumbnail(lang, slug),
      ]);

      final pageJson = results[0] as Map<String, dynamic>?;
      final thumbnailUrl = results[1] as String?;

      if (pageJson == null) return null;

      final content = WikipediaContent.fromApiResponse(
        pageJson: pageJson,
        lang: lang,
        slug: slug,
        thumbnailUrl: thumbnailUrl,
      );

      if (!content.hasContent) return null;

      await _saveToCache(cacheKey, content);
      return content;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchExtract(String lang, String slug) async {
    try {
      final url = Uri.https(
        '$lang.wikipedia.org',
        '/w/api.php',
        {
          'action': 'query',
          'titles': slug,
          'prop': 'extracts',
          'explaintext': 'true',
          'exsectionformat': 'plain',
          'format': 'json',
          'utf8': '1',
          'redirects': '1',
          'origin': '*',
        },
      );

      final response = await http
          .get(url, headers: {
            'Accept': 'application/json',
            'User-Agent': 'PeruEterno/3.0 (flutter; educational)',
          })
          .timeout(_requestTimeout);

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final pages = (body['query'] as Map<String, dynamic>?)?['pages']
          as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) return null;

      final pageJson = pages.values.first as Map<String, dynamic>;
      if (pageJson['pageid'] == null) return null;
      return pageJson;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchThumbnail(String lang, String slug) async {
    try {
      final url = Uri.https(
        '$lang.wikipedia.org',
        '/w/api.php',
        {
          'action': 'query',
          'titles': slug,
          'prop': 'pageimages',
          'pithumbsize': '500',
          'format': 'json',
          'utf8': '1',
          'redirects': '1',
          'origin': '*',
        },
      );

      final response = await http
          .get(url, headers: {
            'Accept': 'application/json',
            'User-Agent': 'PeruEterno/3.0 (flutter; educational)',
          })
          .timeout(_requestTimeout);

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final pages = (body['query'] as Map<String, dynamic>?)?['pages']
          as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) return null;

      final pageJson = pages.values.first as Map<String, dynamic>;
      final thumbnail = pageJson['thumbnail'] as Map<String, dynamic>?;
      return thumbnail?['source'] as String?;
    } catch (_) {
      return null;
    }
  }
}
