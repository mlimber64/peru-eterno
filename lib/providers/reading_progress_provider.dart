import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_progress_sync_service.dart';

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
  static const _kRead = 'rp_read';

  SharedPreferences? _prefs;

  String? lastArticleId;
  String? lastStageId;
  int lastProgress = 0;

  Map<String, int> _progress = {};
  List<ArticleHistoryEntry> _history = [];
  Set<String> _read = {};

  bool get hasLastArticle => lastArticleId != null;
  bool get hasHistory => _history.isNotEmpty;
  List<ArticleHistoryEntry> get history => List.unmodifiable(_history);

  int progressFor(String articleId) => _progress[articleId] ?? 0;
  bool isCompleted(String articleId) => progressFor(articleId) >= 90;

  /// ¿El usuario marcó (manualmente o al llegar al final) este artículo como
  /// leído? A diferencia de [isCompleted] (derivado del % de scroll, que
  /// fluctúa si el usuario vuelve a subir), esto es un estado explícito y
  /// no retrocede solo.
  bool isRead(String articleId) => _read.contains(articleId);

  /// Ids de artículos marcados como leídos. Expuesto (junto con [isRead])
  /// para que [UserProgressSyncService] pueda fusionar con
  /// `user_chapter_progress.is_read` sin acceder a campos privados.
  Set<String> get readArticleIds => Set.unmodifiable(_read);

  /// Marca o desmarca un artículo como leído explícitamente (botón "Marcar
  /// como leído" del lector).
  Future<void> setRead(String articleId, bool read) async {
    if (read) {
      _read.add(articleId);
    } else {
      _read.remove(articleId);
    }
    notifyListeners();
    await _save();
    if (read) {
      unawaited(UserProgressSyncService.instance?.pushChapterProgress(articleId));
    }
  }

  /// Añade [ids] al conjunto de leídos ya fusionado (máximo/unión entre
  /// local y remoto, resuelto por [UserProgressSyncService]) y persiste. No
  /// dispara push de vuelta — el propio servicio de sync ya hizo ese lado.
  Future<void> applySyncedReadIds(Set<String> ids) async {
    final before = _read.length;
    _read.addAll(ids);
    if (_read.length == before) return; // Sin novedades: nada que persistir.
    notifyListeners();
    await _save();
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    lastArticleId = await _safeGetString(_kLastArticle);
    lastStageId = await _safeGetString(_kLastStage);
    lastProgress = await _safeGetInt(_kLastPct) ?? 0;

    if (lastArticleId != null &&
        (lastStageId == null ||
            lastStageId!.isEmpty ||
            lastStageId == 'unknown')) {
      lastStageId = 'peru_prehispanico';
    }

    _progress = await _loadProgress();
    _history = await _loadHistory();
    _read = await _loadRead();

    notifyListeners();
  }

  Future<String?> _safeGetString(String key) async {
    final p = _prefs;
    if (p == null) return null;
    try {
      return p.getString(key);
    } catch (_) {
      await p.remove(key);
      return null;
    }
  }

  Future<int?> _safeGetInt(String key) async {
    final p = _prefs;
    if (p == null) return null;
    try {
      return p.getInt(key);
    } catch (_) {
      await p.remove(key);
      return null;
    }
  }

  Future<Map<String, int>> _loadProgress() async {
    final p = _prefs;
    if (p == null) return {};

    try {
      final raw = p.getString(_kProgress);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('Invalid progress');
      final progress = <String, int>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is int) {
          progress[key] = value.clamp(0, 100);
        } else if (value is num) {
          progress[key] = value.round().clamp(0, 100);
        }
      }
      return progress;
    } catch (_) {
      await p.remove(_kProgress);
      return {};
    }
  }

  Future<Set<String>> _loadRead() async {
    final p = _prefs;
    if (p == null) return {};

    try {
      final raw = p.getString(_kRead);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Invalid read set');
      return decoded.whereType<String>().toSet();
    } catch (_) {
      await p.remove(_kRead);
      return {};
    }
  }

  Future<List<ArticleHistoryEntry>> _loadHistory() async {
    final p = _prefs;
    if (p == null) return [];

    try {
      final raw = p.getString(_kHistory);
      if (raw == null) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Invalid history');
      return decoded
          .whereType<Map>()
          .map((e) => ArticleHistoryEntry.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .where((e) => e.articleId.isNotEmpty)
          .map((e) => e.stageId.isEmpty || e.stageId == 'unknown'
              ? ArticleHistoryEntry(
                  articleId: e.articleId,
                  stageId: 'peru_prehispanico',
                )
              : e)
          .toList();
    } catch (_) {
      await p.remove(_kHistory);
      return [];
    }
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
    // Llegar al final del artículo lo marca como leído automáticamente. No se
    // desmarca si el usuario vuelve a subir: eso solo lo hace el usuario
    // explícitamente con [setRead].
    final justFinishedReading = pct >= 90 && _read.add(articleId);

    notifyListeners();
    await _save();
    if (justFinishedReading) {
      unawaited(UserProgressSyncService.instance?.pushChapterProgress(articleId));
    }
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
    await p.setString(_kRead, jsonEncode(_read.toList()));
  }

  /// Borra todo el progreso de lectura local (último artículo, porcentajes,
  /// historial y capítulos marcados como leídos). Lo usa
  /// `AccountDataService` al ejecutar "Borrar mis datos"; no empuja nada a
  /// Supabase porque ese borrado remoto ya lo hizo el servicio.
  Future<void> resetProgress() async {
    lastArticleId = null;
    lastStageId = null;
    lastProgress = 0;
    _progress = {};
    _history = [];
    _read = {};
    notifyListeners();

    final p = _prefs;
    if (p == null) return;
    await p.remove(_kLastArticle);
    await p.remove(_kLastStage);
    await p.remove(_kLastPct);
    await p.remove(_kProgress);
    await p.remove(_kHistory);
    await p.remove(_kRead);
  }
}
