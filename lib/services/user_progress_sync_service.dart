import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/interactive_story_repository.dart';
import '../providers/collectibles_provider.dart';
import '../providers/daily_story_provider.dart';
import '../providers/interactive_story_provider.dart';
import '../providers/reading_progress_provider.dart';
import 'supabase_auth_service.dart';

/// Sincroniza el progreso del usuario (racha, capítulos leídos, quiz,
/// coleccionables, finales de Narrativa Interactiva) entre SharedPreferences
/// (local, siempre la fuente de verdad inmediata para la UI) y Supabase.
///
/// Offline-first estricto: los 4 providers de progreso escriben en local de
/// forma síncrona como siempre lo hicieron (sus APIs públicas no cambian) y
/// además, si hay un `userId` activo, disparan un push en segundo plano a
/// través de [instance]. Este servicio nunca bloquea ni lanza — cualquier
/// fallo de red deja el estado local intacto y se resuelve en el próximo
/// [syncAll] exitoso.
///
/// [syncAll] (pull + merge + push) corre una vez por sesión de auth, cuando
/// [SupabaseAuthService.userId] pasa a tener valor (login anónimo o, si en
/// el futuro se agrega reintento de red, reconexión). Reglas de fusión: para
/// contadores (racha) se toma el máximo; para conjuntos (coleccionables,
/// capítulos leídos, finales) la unión; el puntaje de quiz por capítulo
/// también toma el máximo.
class UserProgressSyncService {
  /// Instancia activa, asignada una vez en `main.dart` tras construir los 4
  /// providers de progreso. Los providers la usan (`instance?.pushXxx(...)`)
  /// para no depender de Supabase directamente ni de un orden de
  /// construcción que los obligaría a conocer este servicio en su propio
  /// constructor (evita una dependencia circular provider ↔ sync).
  static UserProgressSyncService? instance;

  final SupabaseClient? _client;
  final SupabaseAuthService _auth;
  final DailyStoryProvider _daily;
  final CollectiblesProvider _collectibles;
  final ReadingProgressProvider _reading;
  final InteractiveStoryProvider _interactiveStory;

  bool _syncing = false;

  UserProgressSyncService({
    required SupabaseClient? client,
    required SupabaseAuthService auth,
    required DailyStoryProvider dailyStoryProvider,
    required CollectiblesProvider collectiblesProvider,
    required ReadingProgressProvider readingProgressProvider,
    required InteractiveStoryProvider interactiveStoryProvider,
  })  : _client = client,
        _auth = auth,
        _daily = dailyStoryProvider,
        _collectibles = collectiblesProvider,
        _reading = readingProgressProvider,
        _interactiveStory = interactiveStoryProvider {
    _auth.userId.addListener(_onUserIdChanged);
    _onUserIdChanged(); // Por si ya había sesión (userId ya no-null al crear).
  }

  String? get _uid => _auth.userId.value;

  void _onUserIdChanged() {
    if (_uid != null) unawaited(syncAll());
  }

  /// Pull de Supabase + merge con lo local (regla de máximo/unión) + push
  /// del resultado consolidado + refresco de los providers en memoria.
  /// Nunca lanza; sin red o sin Supabase configurado, es un no-op silencioso.
  Future<void> syncAll() async {
    final client = _client;
    final uid = _uid;
    if (client == null || uid == null || _syncing) return;
    _syncing = true;
    try {
      await Future.wait([
        _syncStreak(client, uid),
        _syncChapterProgress(client, uid),
        _syncCollectibles(client, uid),
        _syncStoryEndings(client, uid),
      ]);
    } catch (_) {
      // Sin red / error del servicio a mitad de sync — lo que ya se haya
      // fusionado queda aplicado; el resto se reintentará en el próximo
      // syncAll() (p. ej. el siguiente arranque de la app).
    } finally {
      _syncing = false;
    }
  }

  // ── Racha ──────────────────────────────────────────────────────────────

  Future<void> _syncStreak(SupabaseClient client, String uid) async {
    final remote = await client
        .from('user_streaks')
        .select()
        .eq('user_id', uid)
        .maybeSingle();

    final remoteCurrent = remote?['current_streak'] as int? ?? 0;
    final remoteMax = remote?['max_streak'] as int? ?? 0;
    final remoteDate = remote?['last_completed_date'] as String?;

    final localCurrent = _daily.currentStreak;
    final localWins = localCurrent >= remoteCurrent;

    final mergedCurrent = localCurrent > remoteCurrent ? localCurrent : remoteCurrent;
    final mergedMax =
        _daily.longestStreak > remoteMax ? _daily.longestStreak : remoteMax;
    final mergedDate = localWins ? _daily.lastReadDate : remoteDate;

    await _daily.applySyncedStreak(
      currentStreak: mergedCurrent,
      longestStreak: mergedMax,
      lastCompletedDate: mergedDate,
    );

    await client.from('user_streaks').upsert({
      'user_id': uid,
      'current_streak': mergedCurrent,
      'max_streak': mergedMax,
      'last_completed_date': mergedDate,
    }, onConflict: 'user_id');
  }

  /// Push incremental de la racha tras [DailyStoryProvider.completeToday].
  /// Escribe el estado local actual tal cual — el próximo [syncAll] resuelve
  /// cualquier conflicto con lo que haya en otro dispositivo.
  Future<void> pushStreak() async {
    final client = _client;
    final uid = _uid;
    if (client == null || uid == null) return;
    try {
      await client.from('user_streaks').upsert({
        'user_id': uid,
        'current_streak': _daily.currentStreak,
        'max_streak': _daily.longestStreak,
        'last_completed_date': _daily.lastReadDate,
      }, onConflict: 'user_id');
    } catch (_) {
      // Sin red — se resincroniza en el próximo syncAll().
    }
  }

  // ── Capítulos leídos + quiz ───────────────────────────────────────────

  Future<void> _syncChapterProgress(SupabaseClient client, String uid) async {
    final remoteRows = await client
        .from('user_chapter_progress')
        .select('chapter_id, is_read, quiz_score')
        .eq('user_id', uid);

    final mergedRead = <String>{..._reading.readArticleIds};
    final mergedScores = <String, int>{..._collectibles.quizScores};

    for (final row in (remoteRows as List).cast<Map<String, dynamic>>()) {
      final chapterId = row['chapter_id'] as String;
      if (row['is_read'] == true) mergedRead.add(chapterId);
      final remoteScore = row['quiz_score'] as int?;
      if (remoteScore != null &&
          remoteScore > (mergedScores[chapterId] ?? -1)) {
        mergedScores[chapterId] = remoteScore;
      }
    }

    await _reading.applySyncedReadIds(mergedRead);
    await _collectibles.applySyncedQuizScores(mergedScores);

    final chapterIds = {...mergedRead, ...mergedScores.keys};
    if (chapterIds.isEmpty) return;
    await client.from('user_chapter_progress').upsert(
      [
        for (final id in chapterIds)
          {
            'user_id': uid,
            'chapter_id': id,
            'is_read': mergedRead.contains(id),
            'quiz_score': mergedScores[id],
          },
      ],
      onConflict: 'user_id,chapter_id',
    );
  }

  /// Push incremental de un capítulo (leído y/o puntaje de quiz) tras
  /// [ReadingProgressProvider.setRead]/`updateProgress` o
  /// [CollectiblesProvider.recordQuizScore]. Siempre envía el estado local
  /// completo y actual de ambas fuentes para ese capítulo — nunca un parche
  /// parcial — así nunca sobreescribe con datos viejos.
  Future<void> pushChapterProgress(String chapterId) async {
    final client = _client;
    final uid = _uid;
    if (client == null || uid == null) return;
    try {
      await client.from('user_chapter_progress').upsert({
        'user_id': uid,
        'chapter_id': chapterId,
        'is_read': _reading.isRead(chapterId),
        'quiz_score': _collectibles.bestScoreFor(chapterId),
      }, onConflict: 'user_id,chapter_id');
    } catch (_) {
      // Sin red — se resincroniza en el próximo syncAll().
    }
  }

  // ── Coleccionables ────────────────────────────────────────────────────

  Future<void> _syncCollectibles(SupabaseClient client, String uid) async {
    final remoteRows = await client
        .from('user_collectibles')
        .select('collectible_id, unlocked_at')
        .eq('user_id', uid);

    final merged = <String, DateTime>{..._collectibles.unlockedAtMap};
    for (final row in (remoteRows as List).cast<Map<String, dynamic>>()) {
      final id = row['collectible_id'] as String;
      final remoteAt = DateTime.parse(row['unlocked_at'] as String);
      final localAt = merged[id];
      if (localAt == null || remoteAt.isBefore(localAt)) merged[id] = remoteAt;
    }

    await _collectibles.applySyncedUnlocks(merged);

    if (merged.isEmpty) return;
    await client.from('user_collectibles').upsert(
      [
        for (final entry in merged.entries)
          {
            'user_id': uid,
            'collectible_id': entry.key,
            'unlocked_at': entry.value.toIso8601String(),
          },
      ],
      onConflict: 'user_id,collectible_id',
    );
  }

  /// Push incremental tras [CollectiblesProvider.unlockCard].
  Future<void> pushCollectible(String collectibleId) async {
    final client = _client;
    final uid = _uid;
    if (client == null || uid == null) return;
    final unlockedAt = _collectibles.unlockedAtMap[collectibleId];
    if (unlockedAt == null) return;
    try {
      await client.from('user_collectibles').upsert({
        'user_id': uid,
        'collectible_id': collectibleId,
        'unlocked_at': unlockedAt.toIso8601String(),
      }, onConflict: 'user_id,collectible_id');
    } catch (_) {
      // Sin red — se resincroniza en el próximo syncAll().
    }
  }

  // ── Finales de Narrativa Interactiva ──────────────────────────────────

  Future<void> _syncStoryEndings(SupabaseClient client, String uid) async {
    final stories = await InteractiveStoryRepository.loadAllStories();
    if (stories.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    final remoteRows = await client
        .from('user_story_endings')
        .select('story_id, ending_node_id')
        .eq('user_id', uid);
    final remoteByStory = <String, Set<String>>{};
    for (final row in (remoteRows as List).cast<Map<String, dynamic>>()) {
      final storyId = row['story_id'] as String;
      (remoteByStory[storyId] ??= {}).add(row['ending_node_id'] as String);
    }

    final pushRows = <Map<String, dynamic>>[];
    for (final story in stories) {
      final localKey = '${InteractiveStoryProvider.kUnlockedEndingsPrefix}${story.id}';
      final local = (prefs.getStringList(localKey) ?? const []).toSet();
      final remote = remoteByStory[story.id] ?? const <String>{};
      final merged = {...local, ...remote};
      if (merged.isEmpty) continue;

      await _interactiveStory.applySyncedEndings(story.id, merged);
      for (final endingNodeId in merged) {
        pushRows.add({
          'user_id': uid,
          'story_id': story.id,
          'ending_node_id': endingNodeId,
        });
      }
    }

    if (pushRows.isEmpty) return;
    await client.from('user_story_endings').upsert(
      pushRows,
      onConflict: 'user_id,story_id,ending_node_id',
      ignoreDuplicates: true,
    );
  }

  /// Push incremental de un final recién desbloqueado, tras
  /// `InteractiveStoryProvider._unlockEnding`.
  Future<void> pushStoryEnding(String storyId, String endingNodeId) async {
    final client = _client;
    final uid = _uid;
    if (client == null || uid == null) return;
    try {
      await client.from('user_story_endings').upsert({
        'user_id': uid,
        'story_id': storyId,
        'ending_node_id': endingNodeId,
      }, onConflict: 'user_id,story_id,ending_node_id', ignoreDuplicates: true);
    } catch (_) {
      // Sin red — se resincroniza en el próximo syncAll().
    }
  }
}
