import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pide la valoración en la tienda, pero solo cuando toca.
///
/// Las reseñas son posicionamiento en Play, y la diferencia entre pedirlas
/// bien o mal es enorme: interrumpir a alguien nada más abrir la app produce
/// una estrella; pedírselo justo después de un logro produce cinco.
///
/// Reglas, pensadas para no quemar la única oportunidad que da Google (la
/// hoja nativa solo aparece unas pocas veces al año por usuario, y si se
/// gasta en mal momento no vuelve):
///
///   1. Nunca antes de [_minGoodMoments] momentos buenos. Uno solo puede ser
///      casualidad; tres es alguien que está disfrutando la app.
///   2. Una sola petición por versión de la app.
///   3. Nunca dos veces en menos de [_minDaysBetween] días.
///   4. Si el usuario ya valoró, no se le vuelve a pedir nunca.
class ReviewPromptService {
  static const int _minGoodMoments = 3;
  static const int _minDaysBetween = 60;

  static const String _kGoodMoments = 'review_good_moments';
  static const String _kLastAskedAt = 'review_last_asked_at';
  static const String _kAskedForVersion = 'review_asked_version';

  final InAppReview _inAppReview;
  final String _appVersion;

  ReviewPromptService({
    required String appVersion,
    InAppReview? inAppReview,
  })  : _appVersion = appVersion,
        _inAppReview = inAppReview ?? InAppReview.instance;

  /// Registra un momento bueno (quiz superado, carta desbloqueada, final de
  /// historia alcanzado) y pide la valoración si se cumplen las condiciones.
  ///
  /// Nunca lanza y nunca bloquea: se llama con `unawaited` desde la UI.
  Future<void> registerGoodMoment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final moments = (prefs.getInt(_kGoodMoments) ?? 0) + 1;
      await prefs.setInt(_kGoodMoments, moments);

      if (!shouldAsk(
        goodMoments: moments,
        lastAskedAt: _readDate(prefs, _kLastAskedAt),
        askedForVersion: prefs.getString(_kAskedForVersion),
        currentVersion: _appVersion,
        now: DateTime.now(),
      )) {
        return;
      }

      if (!await _inAppReview.isAvailable()) return;

      await prefs.setString(_kLastAskedAt, DateTime.now().toIso8601String());
      await prefs.setString(_kAskedForVersion, _appVersion);
      await _inAppReview.requestReview();
    } catch (e) {
      if (kDebugMode) debugPrint('ReviewPromptService: $e');
    }
  }

  /// La decisión, aislada para poder probarla sin tienda ni disco.
  @visibleForTesting
  static bool shouldAsk({
    required int goodMoments,
    required DateTime? lastAskedAt,
    required String? askedForVersion,
    required String currentVersion,
    required DateTime now,
  }) {
    if (goodMoments < _minGoodMoments) return false;
    if (askedForVersion == currentVersion) return false;
    if (lastAskedAt != null &&
        now.difference(lastAskedAt).inDays < _minDaysBetween) {
      return false;
    }
    return true;
  }

  static DateTime? _readDate(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    return raw == null ? null : DateTime.tryParse(raw);
  }
}
