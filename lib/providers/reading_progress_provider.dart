import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which HistoriaArticles the user has opened and how far they've read.
class ArticleHistoryEntry {
  final String articleId;
  final String stageId;

  const ArticleHistoryEntry({
    required this.articleId,
    required this.stageId,
  });

  factory ArticleHistoryEntry.fromJson(Map<String, dynamic> j) =>
      ArticleHistoryEntry(
        articleId: j['a'] as String,
        stageId: j['s'] as String,
      );

  Map<String, dynamic> toJson() => {'a': articleId, 's': stageId};
}

class ReadingProgressProvider extends ChangeNotifier {
  static const _kLastArticle = 'rp_last_article';
  static const _kLastStage = 'rp_last_stage';
  static const _kLastPct = 'rp_last_pct';
  static const _kProgress = 'rp_progress';
  static const _kHistory = 'rp_history';

  SharedPreferences? _prefs;

  String? lastArticleId;
  String? lastStageId;
  int lastProgress = 0;

  Map<String, int> _progress = {};
  List<ArticleHistoryEntry> _history = [];

  bool get hasLastArticle => lastArticleId != null;
  bool get hasHistory => _history.isNotEmpty;
  List<ArticleHistoryEntry> get history => List.unmodifiable(_history);

  int progressFor(String articleId) => _progress[articleId] ?? 0;
  bool isCompleted(String articleId) => progressFor(articleId) >= 90;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    lastArticleId = _prefs!.getString(_kLastArticle);
    lastStageId = _prefs!.getString(_kLastStage);
    lastProgress = _prefs!.getInt(_kLastPct) ?? 0;

    final pJson = _prefs!.getString(_kProgress);
    if (pJson != null) {
      _progress =
          Map<String, int>.from(jsonDecode(pJson) as Map);
    }

    final hJson = _prefs!.getString(_kHistory);
    if (hJson != null) {
      _history = (jsonDecode(hJson) as List)
          .map((e) =>
              ArticleHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    notifyListeners();
  }

  Future<void> openArticle(String articleId, String stageId) async {
    lastArticleId = articleId;
    lastStageId = stageId;
    lastProgress = _progress[articleId] ?? 0;

    _history.removeWhere((e) => e.articleId == articleId);
    _history.insert(
        0, ArticleHistoryEntry(articleId: articleId, stageId: stageId));
    if (_history.length > 20) _history = _history.sublist(0, 20);

    notifyListeners();
    await _save();
  }

  Future<void> updateProgress(String articleId, int percentage) async {
    final pct = percentage.clamp(0, 100);
    final prev = _progress[articleId] ?? 0;
    // Debounce: only write when change is meaningful
    if ((pct - prev).abs() < 4 && pct < 98) return;

    _progress[articleId] = pct;
    if (articleId == lastArticleId) lastProgress = pct;

    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;

    if (lastArticleId != null) {
      await p.setString(_kLastArticle, lastArticleId!);
      await p.setString(_kLastStage, lastStageId ?? '');
      await p.setInt(_kLastPct, lastProgress);
    }
    await p.setString(_kProgress, jsonEncode(_progress));
    await p.setString(
      _kHistory,
      jsonEncode(_history.map((e) => e.toJson()).toList()),
    );
  }
}
