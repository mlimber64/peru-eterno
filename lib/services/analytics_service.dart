import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_info.dart';
import 'supabase_auth_service.dart';

/// Un evento listo para enviar.
///
/// [name] y [target] son identificadores en minúsculas, nunca texto escrito
/// por el usuario. La base impone la misma forma con dos `check`
/// (ver `supabase/migrations/20260902_analytics.sql`), así que si algún día
/// alguien intenta colar aquí una búsqueda tecleada, el INSERT falla en vez
/// de guardarla en silencio.
@immutable
class AnalyticsEvent {
  final String name;
  final String? target;
  final int? value;

  const AnalyticsEvent(this.name, {this.target, this.value});

  /// Deja [raw] con la forma que exige la base: minúsculas, sin acentos y
  /// solo `a-z 0-9 _ -`, con tope de 100.
  ///
  /// **No es cosmético.** Los eventos se mandan en un solo INSERT por lote,
  /// así que un `target` que incumpla el `check` no se pierde él solo: tumba
  /// las diez filas del lote. Y hay ids reales que lo incumplen —
  /// `terremoto_tapadas_limeñas` lleva eñe—, así que sanear aquí es lo que
  /// evita perder eventos en silencio cada vez que alguien abre ese capítulo.
  static String? slug(String? raw) {
    if (raw == null) return null;
    const acentos = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
    };
    final buffer = StringBuffer();
    for (final char in raw.toLowerCase().split('')) {
      final ascii = acentos[char] ?? char;
      buffer.write(RegExp(r'^[a-z0-9_-]$').hasMatch(ascii) ? ascii : '_');
    }
    var out = buffer.toString();
    if (out.length > 100) out = out.substring(0, 100);
    // El check exige que empiece por letra o dígito.
    out = out.replaceFirst(RegExp(r'^[_-]+'), '');
    return out.isEmpty ? null : out;
  }

  Map<String, dynamic> toRow({
    required String? userId,
    required String sessionId,
    required String locale,
    required bool isPremium,
  }) =>
      {
        if (userId != null) 'user_id': userId,
        'session_id': sessionId,
        'name': name,
        if (slug(target) != null) 'target': slug(target),
        if (value != null) 'value': value,
        'app_version': AppInfo.version,
        'platform': _platformName,
        'locale': locale,
        'is_premium': isPremium,
      };

  static String get _platformName {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }
}

/// A dónde van los eventos. Inyectable para poder probar sin red
/// (ver `test/analytics_test.dart`).
typedef AnalyticsSink = Future<void> Function(List<AnalyticsEvent> batch);

/// Analítica de producto, en el propio Supabase y sin SDK de terceros.
///
/// Responde las cuatro preguntas que deciden qué se construye después del
/// lanzamiento: cuánta gente termina el onboarding, cuántos vuelven al día
/// siguiente, qué capítulos se leen y en qué punto se abandona.
///
/// Reglas que se respetan a rajatabla:
///
///  · **Nunca bloquea ni lanza.** Registrar un evento es `void` y síncrono
///    desde fuera; el envío ocurre después, en segundo plano. Si no hay red o
///    la migración no está aplicada, los eventos se pierden en silencio. Una
///    app no puede fallar porque falle su analítica.
///  · **Nada escrito por el usuario.** Solo nombres del catálogo de abajo e
///    identificadores de contenido.
///  · **Por lotes.** Un INSERT por evento gastaría batería y datos del
///    usuario para nada; se acumulan y se mandan de [batchSize] en
///    [batchSize], o cuando pasa [flushInterval], o al pasar la app a
///    segundo plano (que es cuando de verdad hay que vaciar: si el usuario
///    la cierra, lo que quede en la cola se pierde).
class AnalyticsService {
  // ── Catálogo de eventos ────────────────────────────────────────────────
  // Constantes en vez de cadenas sueltas por el sitio: una errata en
  // `chapter_open` escrita a mano crea un evento nuevo que nadie mira, y el
  // embudo sale mal sin que salte ningún error.

  /// Arranque de la app. La base de todo: sesiones y usuarios activos.
  static const appOpen = 'app_open';

  /// El usuario llegó al final del onboarding, o lo saltó. La diferencia
  /// entre ambos dice si las tres pantallas convencen o estorban.
  static const onboardingComplete = 'onboarding_complete';
  static const onboardingSkip = 'onboarding_skip';

  /// Abrió la historia del día / la terminó. El gancho de la racha: si la
  /// distancia entre estos dos es grande, el capítulo se está abandonando a
  /// medias.
  static const dailyOpen = 'daily_open';
  static const dailyComplete = 'daily_complete';

  /// Abrió un capítulo del archivo (`target` = id del capítulo).
  static const chapterOpen = 'chapter_open';

  /// Terminó un quiz (`target` = capítulo, `value` = aciertos 0-3).
  static const quizComplete = 'quiz_complete';

  /// Desbloqueó una carta (`target` = id de la carta).
  static const cardUnlock = 'card_unlock';

  /// Vio el paywall (`target` = de dónde venía: `stage_lock`, `coming_soon`,
  /// `audio`, `menu`…). Es el dato más accionable de todos: dice qué
  /// candado empuja de verdad a pagar.
  static const paywallView = 'paywall_view';

  /// Empezó la prueba gratuita / completó una compra (`target` = plan).
  static const trialStart = 'trial_start';
  static const purchaseSuccess = 'purchase_success';

  /// Narrativa interactiva: empezó una historia / llegó a un final
  /// (`target` = id de la historia).
  static const storyStart = 'story_start';
  static const storyEnding = 'story_ending';

  /// Compartió algo (`target` = qué: `card`, `story_ending`).
  static const share = 'share';

  /// Activó el recordatorio diario. Junto con la racha, dice si las
  /// notificaciones ayudan o si la gente las apaga.
  static const reminderEnable = 'reminder_enable';

  // ── Configuración ──────────────────────────────────────────────────────

  /// Cuántos eventos se acumulan antes de mandar el lote.
  static const int batchSize = 10;

  /// Cada cuánto se vacía la cola aunque no se llene.
  static const Duration flushInterval = Duration(seconds: 30);

  /// Tope de eventos en cola. Sin red, la cola crecería sin límite durante
  /// toda la sesión; pasado el tope se descartan los MÁS ANTIGUOS, porque en
  /// analítica lo reciente vale más que lo viejo.
  static const int maxQueued = 200;

  final AnalyticsSink _sink;
  final String sessionId;

  /// `false` en debug por defecto: los eventos de desarrollo ensucian los
  /// números reales, y quien más abre la app durante el desarrollo eres tú.
  final bool enabled;

  final List<AnalyticsEvent> _queue = [];
  Timer? _timer;
  bool _flushing = false;
  AppLifecycleListener? _lifecycle;

  AnalyticsService({
    required AnalyticsSink sink,
    required this.sessionId,
    bool? enabled,
  })  : _sink = sink,
        enabled = enabled ?? !kDebugMode;

  /// UUID v4 para identificar esta ejecución de la app.
  ///
  /// Se genera a mano en vez de añadir el paquete `uuid`: son doce líneas y
  /// la app ya sumó cuatro dependencias nuevas en esta tanda. La columna
  /// `session_id` es de tipo `uuid`, así que hay que respetar el formato —
  /// versión 4 en el dígito 13 y variante 10xx en el 17.
  static String newSessionId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// Construye el servicio que escribe en Supabase.
  ///
  /// Con `client` a `null` (app compilada sin Supabase) el sink es un no-op:
  /// la app funciona exactamente igual, solo que a ciegas.
  factory AnalyticsService.supabase({
    required SupabaseClient? client,
    required SupabaseAuthService auth,
    required String sessionId,
    required String Function() localeProvider,
    required bool Function() premiumProvider,
    bool? enabled,
  }) {
    return AnalyticsService(
      sessionId: sessionId,
      enabled: enabled,
      sink: (batch) async {
        if (client == null || batch.isEmpty) return;
        try {
          await client.from('app_events').insert([
            for (final e in batch)
              e.toRow(
                userId: auth.userId.value,
                sessionId: sessionId,
                locale: localeProvider(),
                isPremium: premiumProvider(),
              ),
          ]);
        } catch (_) {
          // Sin red, tabla inexistente, RLS… se descarta el lote. Reintentar
          // acumularía eventos viejos que ya no dicen nada.
        }
      },
    );
  }

  /// Registra un evento. Síncrono y sin `await` a propósito: quien llama —una
  /// pantalla, un `onTap`— no debe esperar a la red ni tener que acordarse de
  /// capturar nada.
  void log(String name, {String? target, int? value}) {
    if (!enabled) return;
    _queue.add(AnalyticsEvent(name, target: target, value: value));
    if (_queue.length > maxQueued) {
      _queue.removeRange(0, _queue.length - maxQueued);
    }
    if (_queue.length >= batchSize) {
      unawaited(flush());
    } else {
      _timer ??= Timer(flushInterval, () => unawaited(flush()));
    }
  }

  /// Manda lo que haya en cola. Se llama sola; también hay que llamarla al
  /// pasar la app a segundo plano, que es cuando se pierde lo pendiente.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    final batch = List<AnalyticsEvent>.unmodifiable(_queue);
    _queue.clear();
    try {
      await _sink(batch);
    } finally {
      _flushing = false;
    }
  }

  /// Vacía la cola cuando la app pasa a segundo plano.
  ///
  /// Es el momento clave: los eventos se acumulan para no hacer un INSERT por
  /// cada toque, así que si el usuario cierra la app sin que se cumpla el
  /// lote ni el temporizador, lo pendiente se pierde — y justo la última
  /// sesión antes de desinstalar es la que más dice.
  ///
  /// El listener se guarda en el propio servicio, no en una variable suelta
  /// de `main()`: `main()` retorna tras `runApp` y un listener local podría
  /// ser recolectado, mientras que este servicio lo retiene el árbol de
  /// providers durante toda la vida de la app.
  void installLifecycleFlush() {
    _lifecycle?.dispose();
    _lifecycle = AppLifecycleListener(
      onPause: () => unawaited(flush()),
      onDetach: () => unawaited(flush()),
    );
  }

  /// Eventos en cola sin enviar. Para los tests.
  @visibleForTesting
  int get pendingCount => _queue.length;

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }
}
