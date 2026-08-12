import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/historia_stages_repository.dart';
import '../models/historia_article.dart';
import '../models/historia_stage.dart';
import '../services/home_widget_service.dart';
import '../services/user_progress_sync_service.dart';

/// Selecciona la "Historia del Día" (determinista, uniforme sobre los 20
/// capítulos de `assets/data-refactor/`) y gestiona la racha de lectura
/// diaria, persistida en [SharedPreferences].
class DailyStoryProvider extends ChangeNotifier {
  static const _kLastReadDate = 'ds_last_read_date';
  static const _kCurrentStreak = 'ds_current_streak';
  static const _kLongestStreak = 'ds_longest_streak';
  static const _kFreezesUsed = 'ds_freezes_used';

  /// Congeladores de racha de por vida para un usuario Free (Premium tiene
  /// congeladores ilimitados, ver [_reconcileStreak]).
  static const _kFreeFreezeAllowance = 1;

  SharedPreferences? _prefs;

  String? _lastReadDate; // 'yyyy-MM-dd'
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _freezesUsed = 0;

  /// `true` justo después de que [_reconcileStreak] haya usado un congelador
  /// para preservar la racha — bandera de un solo uso para que la UI lo
  /// notifique (ver [consumeStreakFreezeFlag], mismo patrón que
  /// `PremiumProvider.consumeMessage`).
  bool _justUsedStreakFreeze = false;
  bool get justUsedStreakFreeze => _justUsedStreakFreeze;
  void consumeStreakFreezeFlag() => _justUsedStreakFreeze = false;

  HistoriaArticle? _dailyArticle;
  HistoriaStage? _dailyStage;
  List<HistoriaArticle> _dailyStageArticles = const [];

  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;

  /// Fecha ('yyyy-MM-dd') de la última vez que se completó la historia del
  /// día, o `null` si nunca. Expuesto (además de [currentStreak]/
  /// [longestStreak]) para que [UserProgressSyncService] pueda leer y
  /// fusionar la racha con Supabase sin acceder a campos privados.
  String? get lastReadDate => _lastReadDate;

  /// ¿Ya se leyó la historia del día hoy?
  bool get isCompletedToday => _lastReadDate == _dateKey(DateTime.now());

  /// La historia elegida para hoy. `null` mientras carga.
  HistoriaArticle? get dailyArticle => _dailyArticle;
  HistoriaStage? get dailyStage => _dailyStage;
  List<HistoriaArticle> get dailyStageArticles => _dailyStageArticles;
  bool get isReady => _dailyArticle != null;

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> initialize(bool isPremium, String lang) async {
    _prefs = await SharedPreferences.getInstance();
    _lastReadDate = _prefs!.getString(_kLastReadDate);
    _currentStreak = _prefs!.getInt(_kCurrentStreak) ?? 0;
    _longestStreak = _prefs!.getInt(_kLongestStreak) ?? 0;
    _freezesUsed = _prefs!.getInt(_kFreezesUsed) ?? 0;

    await _reconcileStreak(isPremium);
    await _loadDailyStory(lang);

    notifyListeners();
  }

  /// Si la última lectura no fue hoy ni ayer, la racha activa se perdió — a
  /// menos que haya faltado exactamente un día y quede un congelador
  /// disponible (Premium: siempre; Free: uno de por vida), en cuyo caso se
  /// preserva y se consume el congelador. [longestStreak] no se toca:
  /// preserva el récord histórico.
  Future<void> _reconcileStreak(bool isPremium) async {
    if (_lastReadDate == null || _currentStreak == 0) return;
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    if (_lastReadDate == _dateKey(today) || _lastReadDate == _dateKey(yesterday)) {
      return;
    }

    final twoDaysAgo = today.subtract(const Duration(days: 2));
    final canFreeze = isPremium || _freezesUsed < _kFreeFreezeAllowance;
    if (_lastReadDate == _dateKey(twoDaysAgo) && canFreeze) {
      if (!isPremium) {
        _freezesUsed++;
        await _prefs?.setInt(_kFreezesUsed, _freezesUsed);
      }
      _justUsedStreakFreeze = true;
      return;
    }

    _currentStreak = 0;
  }

  Future<void> _loadDailyStory(String lang) async {
    final all = await HistoriaStagesRepository.loadAllArticles();
    if (all.isEmpty) return;

    final dayOfYear =
        DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    final (article, stage) = all[dayOfYear % all.length];
    _dailyArticle = article;
    _dailyStage = stage;
    _dailyStageArticles = await HistoriaStagesRepository.loadArticlesForStage(
      stage.id,
    );

    await HomeWidgetService.updateData(article, lang);
  }

  /// Marca la historia del día como completada y actualiza la racha.
  /// Devuelve `true` solo la primera vez que se completa hoy (para disparar
  /// el feedback festivo una única vez); `false` si ya estaba completada.
  Future<bool> completeToday() async {
    if (isCompletedToday) return false;

    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    _currentStreak =
        _lastReadDate == _dateKey(yesterday) ? _currentStreak + 1 : 1;
    if (_currentStreak > _longestStreak) _longestStreak = _currentStreak;
    _lastReadDate = _dateKey(today);

    notifyListeners();
    await _save();
    unawaited(UserProgressSyncService.instance?.pushStreak());
    return true;
  }

  /// Aplica una racha ya fusionada (máximo entre local y remoto, resuelto
  /// por [UserProgressSyncService]) y la persiste. No dispara push de vuelta
  /// a Supabase — el propio servicio de sync ya hizo ese lado.
  Future<void> applySyncedStreak({
    required int currentStreak,
    required int longestStreak,
    required String? lastCompletedDate,
  }) async {
    if (currentStreak == _currentStreak &&
        longestStreak == _longestStreak &&
        lastCompletedDate == _lastReadDate) {
      return; // Sin cambios: evita un notifyListeners de más.
    }
    _currentStreak = currentStreak;
    _longestStreak = longestStreak;
    _lastReadDate = lastCompletedDate;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    if (_lastReadDate != null) {
      await p.setString(_kLastReadDate, _lastReadDate!);
    }
    await p.setInt(_kCurrentStreak, _currentStreak);
    await p.setInt(_kLongestStreak, _longestStreak);
  }
}
