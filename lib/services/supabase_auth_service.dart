import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Autenticación anónima con Supabase — da a cada instalación un `user_id`
/// estable (sin registro) para poder sincronizar en la nube el progreso que
/// hoy vive solo en SharedPreferences (racha, quiz, coleccionables, finales
/// de historia).
///
/// Sigue el mismo patrón que [SupabaseContentApi]: el cliente es opcional.
/// Si la app se compiló sin `SUPABASE_URL`/`SUPABASE_ANON_KEY`, o no hay red,
/// el servicio queda en modo local silenciosamente — [userId] permanece
/// `null` y el resto de la app (100% funcional offline) no se entera.
class SupabaseAuthService {
  final SupabaseClient? _client;
  SupabaseAuthService(this._client);

  /// Id del usuario anónimo actual, o `null` si Supabase no está configurado,
  /// no hay red, o el inicio de sesión aún no terminó. Es un [ValueNotifier]
  /// para que providers/pantallas puedan escucharlo (`addListener` o
  /// `ValueListenableBuilder`) sin depender de este servicio como
  /// `ChangeNotifier` completo.
  final ValueNotifier<String?> userId = ValueNotifier<String?>(null);

  /// `true` si la app se compiló con las variables de Supabase (no implica
  /// que el sign-in haya tenido éxito — ver [userId]).
  bool get isConfigured => _client != null;

  /// Verifica si ya hay una sesión activa; si no, inicia sesión anónima.
  ///
  /// No lanza nunca: cualquier fallo (sin red, servicio caído, Supabase no
  /// configurado) deja [userId] en `null` y la app sigue funcionando en modo
  /// local. Pensada para llamarse sin `await` desde `main()` — el arranque
  /// de la app no debe esperar a la red.
  Future<void> initialize() async {
    final client = _client;
    if (client == null) return; // Sin SUPABASE_URL/ANON_KEY: modo local.

    try {
      final existing = client.auth.currentUser;
      if (existing != null) {
        userId.value = existing.id;
        return;
      }
      final response = await client.auth.signInAnonymously();
      userId.value = response.user?.id;
    } catch (_) {
      // Sin red / error del servicio — se queda en modo local sin romper
      // el arranque ni el resto de la app.
    }
  }
}
