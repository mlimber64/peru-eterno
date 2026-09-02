import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/collectibles_provider.dart';
import '../providers/daily_story_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import '../providers/interactive_story_provider.dart';
import '../providers/reading_progress_provider.dart';
import 'supabase_auth_service.dart';

/// Resultado de "Borrar mis datos", para que la UI diga la verdad exacta de
/// lo que pasó en vez de un "listo" genérico.
enum AccountDeletionOutcome {
  /// Se borró todo: las filas del servidor y el progreso local.
  full,

  /// Solo había datos locales (la app se compiló sin Supabase o nunca hubo
  /// sesión anónima). El borrado es completo igualmente.
  localOnly,

  /// El progreso local se borró, pero el servidor no respondió (sin red).
  /// Hay que reintentar con conexión para eliminar la copia en la nube.
  remoteFailed,
}

/// Ejecuta el borrado total de los datos del usuario: la copia en Supabase,
/// el progreso guardado en el dispositivo y la propia identidad anónima.
///
/// Existe porque Google Play y App Store exigen una vía dentro de la app
/// para eliminar la cuenta y los datos asociados. La sesión de Perú Eterno
/// es anónima (no hay registro), así que "cuenta" aquí significa el
/// `user_id` que genera Supabase la primera vez que se abre la app.
///
/// Qué NO borra, a propósito:
/// - El idioma elegido (preferencia de interfaz, no dato personal).
/// - El estado de la suscripción premium: es una compra hecha en la tienda,
///   y borrarla dejaría al usuario sin el acceso que pagó. Para cancelar la
///   suscripción hay que ir a Google Play / App Store (así se explica en los
///   Términos de Servicio).
/// - La caché de contenido descargado, que no es información del usuario y
///   ya tiene su propia opción "Limpiar caché" en Ajustes.
class AccountDataService {
  /// Tablas con datos del usuario, en el orden en que se borran. Deben
  /// coincidir con las de `supabase/migrations/` (ver
  /// `20260901_data_deletion.sql`, que añade las policies de DELETE que este
  /// borrado necesita cuando no hay Edge Function desplegada).
  static const List<String> userTables = [
    'user_chapter_progress',
    'user_collectibles',
    'user_story_endings',
    'user_streaks',
    'user_profiles',
  ];

  /// Nombre de la Edge Function que borra también el usuario de `auth.users`
  /// (requiere service_role, imposible desde el cliente). Si no está
  /// desplegada, se cae al borrado de filas vía RLS.
  static const String edgeFunctionName = 'delete-account';

  final SupabaseClient? _client;
  final SupabaseAuthService _auth;
  final DailyStoryProvider _daily;
  final ReadingProgressProvider _reading;
  final CollectiblesProvider _collectibles;
  final InteractiveStoryProvider _interactiveStory;
  final FavoritesProvider _favorites;
  final HistoryProvider _history;

  AccountDataService({
    required SupabaseClient? client,
    required SupabaseAuthService auth,
    required DailyStoryProvider dailyStoryProvider,
    required ReadingProgressProvider readingProgressProvider,
    required CollectiblesProvider collectiblesProvider,
    required InteractiveStoryProvider interactiveStoryProvider,
    required FavoritesProvider favoritesProvider,
    required HistoryProvider historyProvider,
  })  : _client = client,
        _auth = auth,
        _daily = dailyStoryProvider,
        _reading = readingProgressProvider,
        _collectibles = collectiblesProvider,
        _interactiveStory = interactiveStoryProvider,
        _favorites = favoritesProvider,
        _history = historyProvider;

  /// Borra todo. Nunca lanza: informa con [AccountDeletionOutcome].
  ///
  /// El orden importa. Primero el servidor (mientras el `user_id` todavía
  /// existe y la sesión sigue autenticada), después lo local, y solo al
  /// final la sesión: pedir la sesión nueva antes de vaciar lo local haría
  /// que `UserProgressSyncService` volviera a subir el progreso viejo bajo
  /// el `user_id` nuevo.
  Future<AccountDeletionOutcome> deleteEverything() async {
    final client = _client;
    final uid = _auth.userId.value;

    AccountDeletionOutcome outcome;
    if (client == null || uid == null) {
      outcome = AccountDeletionOutcome.localOnly;
    } else {
      final deleted = await _deleteRemote(client, uid);
      outcome = deleted
          ? AccountDeletionOutcome.full
          : AccountDeletionOutcome.remoteFailed;
    }

    await _wipeLocal();

    if (client != null && uid != null) {
      await _auth.resetAnonymousSession();
    }

    return outcome;
  }

  /// Intenta la Edge Function (borra filas + usuario de `auth.users`) y, si
  /// no está disponible, borra al menos las filas propias con las policies
  /// de DELETE. Devuelve `false` solo si ninguna de las dos vías funcionó.
  Future<bool> _deleteRemote(SupabaseClient client, String uid) async {
    try {
      final response = await client.functions.invoke(edgeFunctionName);
      if (response.status >= 200 && response.status < 300) return true;
    } catch (_) {
      // Función no desplegada, sin red, o error del servicio: se intenta
      // el borrado directo de filas más abajo.
    }

    try {
      for (final table in userTables) {
        await client.from(table).delete().eq('user_id', uid);
      }
    } catch (_) {
      return false;
    }

    // Verificación obligatoria, no paranoia: si la migración
    // 20260901_data_deletion.sql no está aplicada, RLS bloquea el DELETE
    // SIN lanzar error — PostgREST responde 204 habiendo borrado 0 filas.
    // Sin este chequeo, la app diría "datos eliminados" con los datos
    // intactos en el servidor, que es exactamente la promesa que no se
    // puede incumplir.
    try {
      for (final table in userTables) {
        final remaining = await client
            .from(table)
            .select('user_id')
            .eq('user_id', uid)
            .limit(1);
        if (remaining.isNotEmpty) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Vacía el progreso guardado en el dispositivo. Cada provider limpia sus
  /// propias claves y notifica, para que la UI abierta se actualice sin
  /// reiniciar la app.
  Future<void> _wipeLocal() async {
    await _daily.resetProgress();
    await _reading.resetProgress();
    await _collectibles.resetProgress();
    await _interactiveStory.resetProgress();
    await _favorites.clearAll();
    await _history.clear();
  }
}
