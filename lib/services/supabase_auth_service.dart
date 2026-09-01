import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de una acción de cuenta (enviar código, verificarlo).
///
/// Nunca expone el mensaje técnico en inglés que devuelve Supabase: lleva una
/// clave i18n que la pantalla resuelve con `t(...)`, igual que
/// `PremiumProvider` con los errores de la tienda.
class AuthActionOutcome {
  final bool ok;
  final String? messageKey;

  const AuthActionOutcome.ok()
      : ok = true,
        messageKey = null;

  const AuthActionOutcome.failed(this.messageKey) : ok = false;

  // Claves i18n de los fallos que el usuario puede encontrarse.
  static const String errInvalidEmail = 'account.err_invalid_email';
  static const String errInvalidCode = 'account.err_invalid_code';
  static const String errNotFound = 'account.err_not_found';
  static const String errAlreadyUsed = 'account.err_already_used';
  static const String errTooMany = 'account.err_too_many';
  static const String errNetwork = 'account.err_network';
  static const String errUnavailable = 'account.err_unavailable';
}

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

  /// Correo con el que el usuario vinculó su cuenta, o `null` si la sesión
  /// sigue siendo anónima. Es lo que distingue "mi progreso solo vive en este
  /// móvil" de "mi progreso lo puedo recuperar en otro".
  final ValueNotifier<String?> linkedEmail = ValueNotifier<String?>(null);

  /// `true` si la app se compiló con las variables de Supabase (no implica
  /// que el sign-in haya tenido éxito — ver [userId]).
  bool get isConfigured => _client != null;

  /// `true` mientras la sesión no tenga correo vinculado: el progreso se
  /// sincroniza, pero se pierde al reinstalar o cambiar de dispositivo,
  /// porque la identidad anónima vive solo en este teléfono.
  bool get isAnonymous => linkedEmail.value == null;

  /// Refleja en [userId] y [linkedEmail] el usuario que haya ahora mismo.
  void _adoptUser(User? user) {
    userId.value = user?.id;
    final email = user?.email;
    linkedEmail.value = (email != null && email.isNotEmpty) ? email : null;
  }

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
        _adoptUser(existing);
        return;
      }
      final response = await client.auth.signInAnonymously();
      _adoptUser(response.user);
    } catch (_) {
      // Sin red / error del servicio — se queda en modo local sin romper
      // el arranque ni el resto de la app.
    }
  }

  /// Cierra la sesión anónima actual y abre una nueva, con un `user_id`
  /// distinto y sin ningún dato asociado.
  ///
  /// La usa `AccountDataService` como último paso de "Borrar mis datos":
  /// tras eliminar las filas del usuario, seguir con el mismo `user_id`
  /// dejaría al usuario "borrado" pero identificable por el mismo id. Debe
  /// llamarse SIEMPRE después de haber limpiado el progreso local, porque el
  /// nuevo `userId` dispara un `syncAll()` que sube el estado local vigente
  /// en ese momento.
  ///
  /// Como [initialize], nunca lanza: si falla, [userId] queda en `null` y la
  /// app sigue en modo local.
  Future<void> resetAnonymousSession() async {
    final client = _client;
    if (client == null) return;

    try {
      await client.auth.signOut();
    } catch (_) {
      // Un signOut fallido (sin red) no debe impedir el resto: la sesión
      // local se descarta igual al pedir una nueva.
    }
    _adoptUser(null);

    try {
      final response = await client.auth.signInAnonymously();
      _adoptUser(response.user);
    } catch (_) {
      // Sin sesión nueva: modo local hasta el próximo arranque.
    }
  }

  // ── Vincular la cuenta a un correo ─────────────────────────────────────────
  //
  // Sin esto, el progreso sincronizado es irrecuperable: la identidad anónima
  // vive en el almacenamiento de la app, así que reinstalar o cambiar de
  // teléfono genera un `user_id` nuevo y las filas viejas quedan huérfanas.
  //
  // Se usa código de 6 dígitos por correo (OTP), no enlace mágico: no depende
  // de deep links, se comporta igual en Android y iOS, y el usuario nunca sale
  // de la app. Son dos flujos:
  //
  //   1. VINCULAR (este dispositivo, sesión anónima con progreso):
  //      [sendLinkCode] → [confirmLink]. Conserva el MISMO `user_id`, así que
  //      el progreso ya sincronizado sigue siendo suyo — no hay migración.
  //   2. RECUPERAR (dispositivo nuevo): [sendSignInCode] → [confirmSignIn].
  //      Cambia el `user_id` al de la cuenta, lo que dispara el `syncAll()` de
  //      `UserProgressSyncService`, que FUSIONA (unión/máximo) lo que hubiera
  //      leído en este móvil con lo que ya tenía la cuenta.

  /// Envía un código de verificación para vincular [email] a la sesión actual.
  Future<AuthActionOutcome> sendLinkCode(String email) {
    return _guard(() async {
      final client = _requireClient();
      await client.auth.updateUser(UserAttributes(email: email.trim()));
      return const AuthActionOutcome.ok();
    });
  }

  /// Confirma el código recibido y deja la cuenta vinculada a [email],
  /// conservando el `user_id` y por tanto todo el progreso ya sincronizado.
  Future<AuthActionOutcome> confirmLink(String email, String code) {
    return _guard(() async {
      final client = _requireClient();
      final response = await client.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.emailChange,
      );
      _adoptUser(response.user ?? client.auth.currentUser);
      return const AuthActionOutcome.ok();
    });
  }

  /// Envía un código para entrar en una cuenta ya existente.
  ///
  /// `shouldCreateUser: false` a propósito: si el correo no corresponde a
  /// ninguna cuenta, queremos decírselo al usuario, no crear en silencio una
  /// cuenta vacía que le haría creer que perdió su progreso.
  Future<AuthActionOutcome> sendSignInCode(String email) {
    return _guard(() async {
      final client = _requireClient();
      await client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: false,
      );
      return const AuthActionOutcome.ok();
    });
  }

  /// Confirma el código y entra en la cuenta existente.
  Future<AuthActionOutcome> confirmSignIn(String email, String code) {
    return _guard(() async {
      final client = _requireClient();
      final response = await client.auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.email,
      );
      _adoptUser(response.user ?? client.auth.currentUser);
      return const AuthActionOutcome.ok();
    });
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const AuthException('Supabase no configurado');
    }
    return client;
  }

  /// Ejecuta [action] traduciendo cualquier fallo a una clave i18n.
  Future<AuthActionOutcome> _guard(
    Future<AuthActionOutcome> Function() action,
  ) async {
    try {
      return await action();
    } on AuthRetryableFetchException catch (_) {
      return const AuthActionOutcome.failed(AuthActionOutcome.errNetwork);
    } on AuthException catch (e) {
      return AuthActionOutcome.failed(_keyForAuthError(e));
    } catch (_) {
      return const AuthActionOutcome.failed(AuthActionOutcome.errNetwork);
    }
  }

  /// Traduce el error de Supabase a la clave i18n del mensaje que ve el
  /// usuario. Se mira primero el `code` (estable) y solo después el texto,
  /// que Supabase puede cambiar entre versiones.
  static String _keyForAuthError(AuthException e) {
    final code = e.code ?? '';
    final text = e.message.toLowerCase();

    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        e.statusCode == '429') {
      return AuthActionOutcome.errTooMany;
    }
    if (code == 'otp_expired' ||
        text.contains('token has expired') ||
        (text.contains('invalid') && text.contains('token'))) {
      return AuthActionOutcome.errInvalidCode;
    }
    if (code == 'email_exists' || text.contains('already been registered')) {
      return AuthActionOutcome.errAlreadyUsed;
    }
    // `otp_disabled` es lo que devuelve Supabase con `shouldCreateUser: false`
    // cuando el correo no corresponde a ninguna cuenta ("Signups not allowed
    // for otp"), no un código inválido — por eso se comprueba aquí y no
    // arriba.
    if (code == 'otp_disabled' ||
        code == 'user_not_found' ||
        code == 'signup_disabled' ||
        text.contains('signups not allowed') ||
        text.contains('user not found')) {
      return AuthActionOutcome.errNotFound;
    }
    if (code == 'validation_failed' || text.contains('invalid email')) {
      return AuthActionOutcome.errInvalidEmail;
    }
    return AuthActionOutcome.errUnavailable;
  }
}
