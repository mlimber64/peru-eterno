import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/historia_stages_repository.dart';
import '../models/collectible_card.dart';
import '../models/historia_stage.dart';
import '../services/user_progress_sync_service.dart';

/// Gestiona el álbum de tarjetas coleccionables: el manifiesto de tarjetas
/// (`assets/data/collectibles.json`, enriquecido con título/imagen del
/// [HistoriaArticle] correspondiente), qué tarjetas desbloqueó el usuario y
/// sus mejores puntajes de quiz por capítulo. Todo persistido en
/// [SharedPreferences].
class CollectiblesProvider extends ChangeNotifier {
  static const _kUnlocked = 'cp_unlocked';
  static const _kUnlockedAt = 'cp_unlocked_at';
  static const _kQuizScores = 'cp_quiz_scores';
  static const _manifestPath = 'assets/data/collectibles.json';

  SharedPreferences? _prefs;

  List<CollectibleCard> _cards = [];
  Map<String, HistoriaStage> _stagesById = {};
  final Set<String> _unlocked = {};
  final Map<String, DateTime> _unlockedAt = {};
  final Map<String, int> _quizScores = {};

  List<CollectibleCard> get cards => List.unmodifiable(_cards);
  int get unlockedCount => _unlocked.length;
  int get totalCount => _cards.length;

  /// Etapas en orden, usadas para agrupar el álbum. `null` hasta que
  /// [initialize] termine de cargar.
  List<HistoriaStage> get stagesInOrder =>
      _stagesById.values.toList()..sort((a, b) => a.orden.compareTo(b.orden));
  HistoriaStage? stageFor(String stageId) => _stagesById[stageId];

  bool isUnlocked(String chapterId) => _unlocked.contains(chapterId);
  int? bestScoreFor(String chapterId) => _quizScores[chapterId];

  /// Puntajes de quiz y fecha de desbloqueo por capítulo. Expuestos (junto
  /// con [isUnlocked]/[bestScoreFor]) para que [UserProgressSyncService]
  /// pueda fusionar con Supabase (`user_chapter_progress.quiz_score`,
  /// `user_collectibles.unlocked_at`) sin acceder a campos privados.
  Map<String, int> get quizScores => Map.unmodifiable(_quizScores);
  Map<String, DateTime> get unlockedAtMap => Map.unmodifiable(_unlockedAt);

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _unlocked.addAll(_prefs!.getStringList(_kUnlocked) ?? const []);
    _quizScores.addAll(await _loadQuizScores());
    _unlockedAt.addAll(await _loadUnlockedAt());

    await _loadCards();
    notifyListeners();
  }

  Future<Map<String, int>> _loadQuizScores() async {
    final raw = _prefs?.getString(_kQuizScores);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, DateTime>> _loadUnlockedAt() async {
    final raw = _prefs?.getString(_kUnlockedAt);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, DateTime.parse(v as String)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _loadCards() async {
    final raw = await rootBundle.loadString(_manifestPath);
    final manifest = jsonDecode(raw) as List<dynamic>;
    final articles = await HistoriaStagesRepository.loadAllArticles();
    final articlesById = {for (final (a, _) in articles) a.id: a};
    _stagesById = {for (final (_, s) in articles) s.id: s};

    _cards = manifest.map((entry) {
      final map = entry as Map<String, dynamic>;
      final id = map['id'] as String;
      final article = articlesById[id];
      return CollectibleCard(
        id: id,
        stageId: map['stage_id'] as String,
        rarity: CardRarityX.fromString(map['rareza'] as String),
        titulo: article?.titulo ?? const {},
        imagen: article?.imagenAssetPath ?? '',
        descripcion: article?.subtitulo ?? const {},
        isUnlocked: _unlocked.contains(id),
        unlockedAt: _unlockedAt[id],
      );
    }).toList();
  }

  /// Guarda el mejor puntaje de un quiz (0-3) para el capítulo [chapterId].
  Future<void> recordQuizScore(String chapterId, int score) async {
    final prev = _quizScores[chapterId] ?? -1;
    if (score <= prev) return;
    _quizScores[chapterId] = score;
    notifyListeners();
    final p = _prefs;
    if (p != null) await p.setString(_kQuizScores, jsonEncode(_quizScores));
    unawaited(UserProgressSyncService.instance?.pushChapterProgress(chapterId));
  }

  /// Fusiona puntajes ya resueltos (máximo entre local y remoto, resuelto
  /// por [UserProgressSyncService]) y persiste. No dispara push de vuelta.
  Future<void> applySyncedQuizScores(Map<String, int> scores) async {
    var changed = false;
    for (final entry in scores.entries) {
      final prev = _quizScores[entry.key] ?? -1;
      if (entry.value > prev) {
        _quizScores[entry.key] = entry.value;
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    final p = _prefs;
    if (p != null) await p.setString(_kQuizScores, jsonEncode(_quizScores));
  }

  /// Desbloquea la tarjeta de [chapterId]. Devuelve `true` solo la primera
  /// vez que se desbloquea (para disparar la animación de recompensa una
  /// única vez); `false` si ya estaba desbloqueada.
  Future<bool> unlockCard(String chapterId) async {
    if (_unlocked.contains(chapterId)) return false;
    _applyUnlock(chapterId, DateTime.now());
    notifyListeners();
    await _persistUnlocked();
    unawaited(UserProgressSyncService.instance?.pushCollectible(chapterId));
    return true;
  }

  /// Fusiona desbloqueos ya resueltos (unión local ∪ remoto, con la fecha de
  /// desbloqueo más antigua entre ambos lados, resuelto por
  /// [UserProgressSyncService]) y persiste. No dispara push de vuelta.
  Future<void> applySyncedUnlocks(Map<String, DateTime> unlockedAt) async {
    var changed = false;
    for (final entry in unlockedAt.entries) {
      final isNew = !_unlocked.contains(entry.key);
      final earlier = _unlockedAt[entry.key] == null ||
          entry.value.isBefore(_unlockedAt[entry.key]!);
      if (isNew || earlier) {
        _applyUnlock(entry.key, entry.value);
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    await _persistUnlocked();
  }

  /// Marca [chapterId] como desbloqueado (idempotente) y refleja el cambio
  /// en [_cards]. Compartido por [unlockCard] y [applySyncedUnlocks].
  void _applyUnlock(String chapterId, DateTime unlockedAt) {
    _unlocked.add(chapterId);
    _unlockedAt[chapterId] = unlockedAt;
    final idx = _cards.indexWhere((c) => c.id == chapterId);
    if (idx != -1) {
      _cards[idx] = _cards[idx].copyWith(isUnlocked: true, unlockedAt: unlockedAt);
    }
  }

  Future<void> _persistUnlocked() async {
    final p = _prefs;
    if (p == null) return;
    await p.setStringList(_kUnlocked, _unlocked.toList());
    await p.setString(
      _kUnlockedAt,
      jsonEncode(_unlockedAt.map((k, v) => MapEntry(k, v.toIso8601String()))),
    );
  }
}
