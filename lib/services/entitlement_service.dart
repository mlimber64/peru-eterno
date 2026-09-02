import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_auth_service.dart';

/// Acceso premium tal y como lo ve el SERVIDOR.
///
/// [isActive] lo calcula Postgres con su propio reloj (vista `my_entitlement`),
/// no el dispositivo: es la diferencia entre un acceso verificable y uno que
/// se alarga atrasando la hora del teléfono.
class Entitlement {
  /// 'none' | 'weekly' | 'annual' | 'trial'
  final String plan;
  final DateTime? expiresAt;
  final bool trialUsed;
  final bool isActive;

  const Entitlement({
    required this.plan,
    required this.expiresAt,
    required this.trialUsed,
    required this.isActive,
  });

  factory Entitlement.fromJson(Map<String, dynamic> json) => Entitlement(
        plan: json['plan']?.toString() ?? 'none',
        expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
        trialUsed: json['trial_used'] == true,
        isActive: json['is_active'] == true,
      );
}

/// Qué contestó el servidor al pedir la prueba gratuita.
class TrialRequestResult {
  /// Concedida: [entitlement] trae la fecha de fin que puso el servidor.
  final Entitlement? entitlement;

  /// El servidor confirma que esta cuenta ya gastó su prueba.
  final bool alreadyUsed;

  /// No se pudo preguntar (sin red, función sin desplegar, sin sesión). El
  /// cliente decide con lo que sepa localmente.
  final bool unknown;

  const TrialRequestResult.granted(this.entitlement)
      : alreadyUsed = false,
        unknown = false;

  const TrialRequestResult.alreadyUsed()
      : entitlement = null,
        alreadyUsed = true,
        unknown = false;

  const TrialRequestResult.unknown()
      : entitlement = null,
        alreadyUsed = false,
        unknown = true;
}

/// Lee el acceso premium del servidor y manda los recibos de compra a validar.
///
/// Todo lo que hace es opcional por diseño: si Supabase no está configurado,
/// no hay sesión, la migración `20260901_entitlements.sql` no está aplicada o
/// no hay red, devuelve `null` y [PremiumProvider] sigue con su estado local
/// —el comportamiento que la app ya tenía—. Nunca lanza.
class EntitlementService {
  static const String verifyFunctionName = 'verify-purchase';
  static const String startTrialFunctionName = 'start-trial';

  final SupabaseClient? _client;
  final SupabaseAuthService _auth;

  EntitlementService({
    required SupabaseClient? client,
    required SupabaseAuthService auth,
  })  : _client = client,
        _auth = auth;

  bool get isAvailable => _client != null && _auth.userId.value != null;

  /// Acceso vigente según el servidor, o `null` si no se pudo consultar.
  ///
  /// `null` NO significa "sin premium": significa "no lo sé". Quien llama debe
  /// conservar su estado local en ese caso, o un usuario que pagó se quedaría
  /// sin acceso cada vez que abra la app sin cobertura.
  Future<Entitlement?> fetch() async {
    final client = _client;
    if (client == null || _auth.userId.value == null) return null;

    try {
      final rows = await client.from('my_entitlement').select().limit(1);
      if (rows.isEmpty) {
        // Sin fila: el usuario nunca ha comprado ni usado la prueba. Eso sí
        // es una respuesta, no un fallo.
        return const Entitlement(
          plan: 'none',
          expiresAt: null,
          trialUsed: false,
          isActive: false,
        );
      }
      return Entitlement.fromJson(rows.first);
    } catch (_) {
      // Vista inexistente (migración sin aplicar), sin red, sesión caducada…
      return null;
    }
  }

/// Resultado de pedir la prueba gratuita al servidor.
  ///
  /// Distingue tres cosas que la UI necesita separar: se activó, ya se había
  /// usado, o no se pudo saber (y entonces decide el cliente).
  Future<TrialRequestResult> startTrial() async {
    final client = _client;
    if (client == null || _auth.userId.value == null) {
      return const TrialRequestResult.unknown();
    }

    try {
      final response = await client.functions.invoke(startTrialFunctionName);
      if (response.status == 409) {
        return const TrialRequestResult.alreadyUsed();
      }
      if (response.status < 200 || response.status >= 300) {
        return const TrialRequestResult.unknown();
      }
      final data = response.data;
      if (data is! Map) return const TrialRequestResult.unknown();
      return TrialRequestResult.granted(
        Entitlement.fromJson(Map<String, dynamic>.from(data)),
      );
    } on FunctionException catch (e) {
      // `invoke` lanza en respuestas no-2xx: el 409 de "ya usada" llega aquí.
      if (e.status == 409) return const TrialRequestResult.alreadyUsed();
      return const TrialRequestResult.unknown();
    } catch (_) {
      return const TrialRequestResult.unknown();
    }
  }

  /// Manda el recibo de Play a validar. Devuelve el acceso concedido, o `null`
  /// si la validación no está disponible (función sin desplegar, sin
  /// credenciales de Play, sin red).
  ///
  /// Igual que [fetch]: `null` es "no lo sé", no "compra inválida". Una compra
  /// real no puede quedarse sin acceso porque el servidor no conteste.
  Future<Entitlement?> verifyPurchase({
    required String productId,
    required String purchaseToken,
    String platform = 'android',
  }) async {
    final client = _client;
    if (client == null || _auth.userId.value == null) return null;

    try {
      final response = await client.functions.invoke(
        verifyFunctionName,
        body: {
          'productId': productId,
          'purchaseToken': purchaseToken,
          'platform': platform,
        },
      );

      if (response.status < 200 || response.status >= 300) return null;

      final data = response.data;
      if (data is! Map) return null;
      return Entitlement.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return null;
    }
  }
}
