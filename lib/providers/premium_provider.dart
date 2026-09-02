import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/entitlement_service.dart';

/// Estado de la compra premium (suscripción).
enum PremiumStatus {
  /// Sin información todavía / sin comprar.
  idle,

  /// Esperando respuesta de la tienda (flujo de pago abierto).
  pending,

  /// Compra/restauración correcta y verificada.
  purchased,

  /// La compra falló o fue cancelada por el usuario.
  error,
}

/// Plan de suscripción premium.
enum PremiumPlan { none, weekly, annual }

/// Gestiona el desbloqueo premium como **suscripción** (plan semanal o
/// anual, con prueba gratuita de 7 días) usando el plugin oficial
/// `in_app_purchase` para la compra real, con el estado de vigencia
/// (prueba/plan activo, fecha de expiración) resuelto y persistido
/// localmente en [SharedPreferences] — no hay backend de renovación/recibo
/// todavía, así que la expiración es una fecha calculada localmente al
/// comprar/iniciar la prueba, pensada para integrarse más adelante con un
/// verificador server-side (RevenueCat u otro).
///
/// Flujo:
/// 1. [initialize] carga el estado persistido, comprueba disponibilidad de la
///    tienda, se suscribe al `purchaseStream` y consulta los productos.
/// 2. [startFreeTrial] activa la prueba de 7 días sin pasar por la tienda
///    (un solo uso por usuario).
/// 3. [buyPlan] lanza el flujo nativo de compra para el plan elegido.
/// 4. El resultado de una compra real llega **siempre** de forma asíncrona
///    por el stream y se procesa en [_onPurchaseUpdated], que verifica,
///    persiste y **completa** cada transacción
///    ([InAppPurchase.completePurchase]) para que no quede en el limbo.
/// 5. [restorePurchases] re-emite las compras previas por el mismo stream.
class PremiumProvider extends ChangeNotifier {
  PremiumProvider({InAppPurchase? iap, EntitlementService? entitlements})
      : _injectedIap = iap,
        _entitlements = entitlements;

  /// IDs de producto tal cual dados de alta en Play Console / App Store
  /// Connect (suscripciones). Deben coincidir EXACTAMENTE.
  static const String weeklyProductId = 'peru_eterno_premium_weekly';
  static const String annualProductId = 'peru_eterno_premium_annual';

  static const _kPlan = 'premium_plan';
  static const _kExpiresAt = 'premium_expires_at';
  static const _kTrialEndsAt = 'premium_trial_ends_at';
  static const _kHasUsedTrial = 'premium_has_used_trial';

  /// `true` cuando el acceso vigente lo concedió el servidor tras validar el
  /// recibo. Es lo que habilita la revocación: solo se puede quitar el acceso
  /// a partir de una respuesta del servidor si fue él quien lo dio. Sin esta
  /// marca, un backend caído dejaría sin premium a quien pagó.
  static const _kServerVerified = 'premium_server_verified';

  static const Duration _weeklyDuration = Duration(days: 7);
  static const Duration _annualDuration = Duration(days: 365);
  static const Duration _trialDuration = Duration(days: 7);

  // Claves i18n de los mensajes de usuario (resueltas en la UI con `t(...)`).
  // Evitan exponer textos técnicos en inglés de la tienda.
  static const String msgCanceled = 'premium.error_canceled';
  static const String msgFailed = 'premium.error_failed';
  static const String msgUnavailable = 'premium.error_unavailable';
  static const String msgRestoreSuccess = 'premium.restore_success';

  // Resuelto perezosamente: construir un PremiumProvider no debe tener el
  // efecto secundario de tocar el canal de plataforma (registra el cliente
  // de facturación nativo). Solo se resuelve la primera vez que de verdad se
  // necesita (initialize/buyPlan/restorePurchases), lo que además permite
  // instanciar el provider en tests puros sin un entorno de plataforma real.
  final InAppPurchase? _injectedIap;
  InAppPurchase? _iapInstance;
  InAppPurchase get _iap => _injectedIap ?? (_iapInstance ??= InAppPurchase.instance);
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  SharedPreferences? _prefs;

  /// Fuente de verdad del acceso premium cuando está disponible. Opcional:
  /// sin Supabase configurado, sin sesión o sin la migración de
  /// `user_entitlements` aplicada, todo sigue funcionando en local.
  final EntitlementService? _entitlements;

  PremiumPlan _plan = PremiumPlan.none;
  DateTime? _expiresAt;
  DateTime? _trialEndsAt;
  bool _hasUsedTrial = false;

  /// Último acceso conocido según el servidor. `null` = todavía no se ha
  /// podido consultar; NO significa "sin premium".
  Entitlement? _serverEntitlement;
  bool _serverVerified = false;

  bool _storeAvailable = false;
  final Map<String, ProductDetails> _products = {};
  PremiumStatus _status = PremiumStatus.idle;

  // Mensaje de un solo uso para la UI: una clave i18n (error o éxito) que la
  // pantalla muestra una vez y luego limpia con [consumeMessage].
  String? _messageKey;
  bool _messageIsError = false;

  // ── Getters públicos ───────────────────────────────────────────────────────

  /// `true` si el usuario tiene acceso premium vigente (prueba activa o plan
  /// pagado no expirado).
  ///
  /// Orden de decisión, pensado para que ni un servidor caído deje sin acceso
  /// a quien pagó, ni un reloj manipulado se lo regale a quien no:
  ///
  /// 1. Si el servidor dice que hay acceso vigente (`is_active`, calculado con
  ///    SU reloj), lo hay. Fin.
  /// 2. Si el servidor dice que NO y además fue él quien concedió este acceso
  ///    ([_serverVerified]), se revoca — este es el caso de la suscripción
  ///    cancelada o vencida.
  /// 3. En cualquier otro caso (sin respuesta del servidor, o acceso que él
  ///    nunca validó), manda el estado local: es el comportamiento que la app
  ///    tenía y el que mantiene el premium funcionando sin conexión.
  bool get isPremium => resolveIsPremium(
        server: _serverEntitlement,
        serverVerified: _serverVerified,
        now: DateTime.now(),
        trialEndsAt: _trialEndsAt,
        plan: _plan,
        expiresAt: _expiresAt,
      );

  /// La regla de arriba, aislada como función pura para poder probarla.
  ///
  /// Es la lógica que decide quién tiene acceso de pago: merece test propio y
  /// no depender del reloj real ni de una sesión de Supabase.
  @visibleForTesting
  static bool resolveIsPremium({
    required Entitlement? server,
    required bool serverVerified,
    required DateTime now,
    required DateTime? trialEndsAt,
    required PremiumPlan plan,
    required DateTime? expiresAt,
  }) {
    if (server != null) {
      if (server.isActive) return true;
      if (serverVerified) return false;
    }

    if (trialEndsAt != null && now.isBefore(trialEndsAt)) return true;
    if (plan != PremiumPlan.none &&
        expiresAt != null &&
        now.isBefore(expiresAt)) {
      return true;
    }
    return false;
  }

  bool get isInTrial =>
      _trialEndsAt != null && DateTime.now().isBefore(_trialEndsAt!);

  int get daysLeftInTrial {
    if (!isInTrial) return 0;
    return _trialEndsAt!.difference(DateTime.now()).inDays + 1;
  }

  bool get hasUsedTrial => _hasUsedTrial;

  PremiumPlan get currentPlan => _plan;

  /// `true` si la tienda (Play/App Store) está disponible en el dispositivo.
  bool get storeAvailable => _storeAvailable;

  /// Precio formateado por la tienda (ej. "2,99 €/semana"). `null` si no
  /// hay datos de la tienda para ese plan todavía.
  String? localizedPriceFor(PremiumPlan plan) =>
      _products[_productIdFor(plan)]?.price;

  PremiumStatus get status => _status;
  bool get isPurchasePending => _status == PremiumStatus.pending;

  /// Clave i18n del último mensaje a mostrar (error o éxito), o `null` si no
  /// hay nada pendiente. Resolver en la UI con `t(...)`.
  String? get lastError => _messageKey;

  /// `true` si [lastError] representa un error (vs. un mensaje de éxito como
  /// la restauración correcta). Útil para colorear el SnackBar.
  bool get messageIsError => _messageIsError;

  static String _productIdFor(PremiumPlan plan) => switch (plan) {
        PremiumPlan.weekly => weeklyProductId,
        PremiumPlan.annual => annualProductId,
        PremiumPlan.none => '',
      };

  /// Emite un mensaje de un solo uso (clave i18n) y notifica a los listeners.
  void _emitMessage(String key, {required bool isError}) {
    _messageKey = key;
    _messageIsError = isError;
    notifyListeners();
  }

  /// La UI llama a esto tras mostrar el mensaje, para no repetirlo en cada
  /// rebuild. No notifica (evita bucles de reconstrucción).
  void consumeMessage() {
    _messageKey = null;
  }

  // ── Ciclo de vida ──────────────────────────────────────────────────────────

  /// Tiempo máximo que se espera a la tienda antes de darla por no
  /// disponible. Play Billing y StoreKit pueden tardar indefinidamente si el
  /// dispositivo no tiene Play Services o la red está caída, y sin este
  /// límite la app se quedaría esperando una respuesta que no llega.
  static const Duration _storeTimeout = Duration(seconds: 12);

  /// Carga el estado premium persistido. **Solo toca disco local**: es lo
  /// único que `main()` necesita esperar antes de `runApp`.
  ///
  /// La conexión con la tienda va aparte, en [connectStore], precisamente
  /// para que no bloquee el arranque: `isAvailable()` y
  /// `queryProductDetails()` son llamadas al canal nativo de facturación
  /// más red, y esperarlas antes de pintar la primera pantalla dejaba la app
  /// en negro en dispositivos sin Play Services o con mala conexión.
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _plan = _planFromString(_prefs?.getString(_kPlan));
    _expiresAt = _readDate(_kExpiresAt);
    _trialEndsAt = _readDate(_kTrialEndsAt);
    _hasUsedTrial = _prefs?.getBool(_kHasUsedTrial) ?? false;
    _serverVerified = _prefs?.getBool(_kServerVerified) ?? false;
    if (isPremium) _status = PremiumStatus.purchased;
    notifyListeners();
  }

  /// Consulta al servidor cuál es el acceso vigente y lo adopta.
  ///
  /// Pensada para lanzarse sin `await` al arrancar y cada vez que cambie la
  /// sesión (vincular cuenta, entrar en otro dispositivo). Nunca lanza y, si
  /// el servidor no contesta, no toca nada: el estado local sigue mandando.
  Future<void> syncEntitlement() async {
    final service = _entitlements;
    if (service == null) return;

    final entitlement = await service.fetch();
    if (entitlement == null) return; // "No lo sé": conservar lo local.

    _serverEntitlement = entitlement;

    if (entitlement.isActive) {
      // El servidor concede: su fecha de expiración sustituye a la calculada
      // localmente, y se cachea en disco para seguir funcionando sin red.
      if (entitlement.plan == 'trial') {
        _trialEndsAt = entitlement.expiresAt;
        _plan = PremiumPlan.none;
        _expiresAt = null;
      } else {
        _plan = _planFromString(entitlement.plan);
        _expiresAt = entitlement.expiresAt;
        _trialEndsAt = null;
      }
      _serverVerified = true;
      _status = PremiumStatus.purchased;
    } else if (_serverVerified) {
      // El servidor dice que ya no hay acceso y fue él quien lo concedió:
      // suscripción cancelada o vencida. Se revoca de verdad.
      _plan = PremiumPlan.none;
      _expiresAt = null;
      _trialEndsAt = null;
      _status = PremiumStatus.idle;
    }

    // La prueba consumida solo se propaga hacia "usada": si el servidor la da
    // por gastada, no se puede volver atrás borrando datos locales.
    _hasUsedTrial = _hasUsedTrial || entitlement.trialUsed;

    await _persistState();
    notifyListeners();
  }

  Future<void> _persistState() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kPlan, _plan.name);
    await p.setBool(_kHasUsedTrial, _hasUsedTrial);
    await p.setBool(_kServerVerified, _serverVerified);
    if (_expiresAt != null) {
      await p.setString(_kExpiresAt, _expiresAt!.toIso8601String());
    } else {
      await p.remove(_kExpiresAt);
    }
    if (_trialEndsAt != null) {
      await p.setString(_kTrialEndsAt, _trialEndsAt!.toIso8601String());
    } else {
      await p.remove(_kTrialEndsAt);
    }
  }

  /// Conecta con la tienda: disponibilidad, escucha del `purchaseStream` y
  /// precios de los planes. Pensada para lanzarse SIN `await` desde `main()`
  /// (`unawaited(...)`): cuando termina, notifica y la UI ya abierta se
  /// actualiza sola con los precios reales.
  ///
  /// Nunca lanza: cualquier fallo deja `storeAvailable` en `false`, que es
  /// justo lo que la pantalla de premium ya sabe manejar.
  ///
  /// Memoizada: llamarla varias veces devuelve la misma conexión en curso,
  /// nunca abre una segunda suscripción al `purchaseStream`.
  Future<void> connectStore() => _storeConnection ??= _connectStore();

  Future<void>? _storeConnection;

  /// Espera a que termine la conexión con la tienda si sigue en curso.
  ///
  /// Necesario porque [connectStore] ya no bloquea el arranque: sin esto, un
  /// usuario rápido que abre el paywall y pulsa comprar en el primer segundo
  /// se encontraría un "tienda no disponible" que en realidad solo era
  /// "todavía no ha respondido".
  Future<void> _ensureStoreReady() async {
    final pending = _storeConnection;
    if (pending != null) await pending;
  }

  Future<void> _connectStore() async {
    try {
      _storeAvailable = await _iap.isAvailable().timeout(_storeTimeout);
    } catch (_) {
      _storeAvailable = false;
    }

    if (!_storeAvailable) {
      // Solo avisamos si el usuario aún NO es premium: a quien ya está en
      // prueba/plan no tiene sentido molestarlo con un error de tienda al
      // abrir sin conexión.
      if (!isPremium) {
        _emitMessage(msgUnavailable, isError: true);
      } else {
        notifyListeners();
      }
      return;
    }

    // Suscripción al stream ANTES de cualquier compra/restauración, para
    // no perder eventos. Se mantiene viva durante toda la vida de la app.
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object _) {
        // No exponemos el mensaje técnico en inglés: usamos clave i18n.
        _status = PremiumStatus.error;
        _emitMessage(msgFailed, isError: true);
      },
    );

    // Detalles de los productos (semanal + anual).
    try {
      await _loadProducts();
    } catch (_) {
      // Sin precios de la tienda la pantalla cae a sus textos por defecto;
      // no es motivo para dejar el provider en un estado roto.
      notifyListeners();
    }
  }

  Future<void> _loadProducts() async {
    final ids = {weeklyProductId, annualProductId};
    final response = await _iap.queryProductDetails(ids).timeout(_storeTimeout);
    for (final p in response.productDetails) {
      _products[p.id] = p;
    }
    if (kDebugMode && response.notFoundIDs.isNotEmpty) {
      debugPrint(
        'IAP: productos no encontrados: ${response.notFoundIDs}',
      );
    }
    notifyListeners();
  }

  // ── Prueba gratuita ─────────────────────────────────────────────────────────

  /// Activa la prueba gratuita de 7 días. Mock local (no pasa por la
  /// tienda): un solo uso por usuario. Devuelve `false` si ya se usó antes.
  Future<bool> startFreeTrial() async {
    if (_hasUsedTrial) return false;

    // El servidor es quien lleva la cuenta de si esta cuenta ya gastó su
    // prueba: en local se borraba al reinstalar la app, lo que la hacía
    // infinita. Solo si no se le puede preguntar se decide en el dispositivo.
    final service = _entitlements;
    if (service != null) {
      final result = await service.startTrial();
      if (result.alreadyUsed) {
        _hasUsedTrial = true;
        await _persistState();
        notifyListeners();
        return false;
      }
      final granted = result.entitlement;
      if (granted != null) {
        _serverEntitlement = granted;
        _serverVerified = true;
        _hasUsedTrial = true;
        _trialEndsAt = granted.expiresAt;
        _status = PremiumStatus.purchased;
        await _persistState();
        notifyListeners();
        return true;
      }
      // result.unknown: sigue el camino local de abajo.
    }

    _hasUsedTrial = true;
    _trialEndsAt = DateTime.now().add(_trialDuration);
    _status = PremiumStatus.purchased;
    await _persistState();
    notifyListeners();
    return true;
  }

  // ── Acciones de compra ─────────────────────────────────────────────────────

  /// Lanza el flujo nativo de compra para [plan]. El resultado llega por el
  /// stream; observa [isPremium] / [status] para reaccionar en la UI.
  ///
  /// Devuelve `true` si el flujo se pudo iniciar; `false` si la tienda o el
  /// producto no están disponibles.
  Future<bool> buyPlan(PremiumPlan plan) async {
    await _ensureStoreReady();
    final product = _products[_productIdFor(plan)];
    if (!_storeAvailable || product == null) {
      _status = PremiumStatus.error;
      _emitMessage(msgUnavailable, isError: true);
      return false;
    }

    _status = PremiumStatus.pending;
    consumeMessage(); // limpia cualquier mensaje previo antes del nuevo intento
    notifyListeners();

    final purchaseParam = PurchaseParam(productDetails: product);
    return _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Restaura compras previas (obligatorio en App Store; recomendable en Play).
  /// Las compras encontradas llegan por el stream como `restored`.
  Future<void> restorePurchases() async {
    await _ensureStoreReady();
    if (!_storeAvailable) {
      _status = PremiumStatus.error;
      _emitMessage(msgUnavailable, isError: true);
      return;
    }
    _status = PremiumStatus.pending;
    consumeMessage();
    notifyListeners();
    await _iap.restorePurchases();
  }

  // ── Procesamiento del stream ───────────────────────────────────────────────

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final plan = _planForProductId(purchase.productID);
      if (plan == PremiumPlan.none) {
        // Cierra cualquier transacción ajena pendiente para no bloquear la cola.
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _status = PremiumStatus.pending;
          notifyListeners();
          break;

        case PurchaseStatus.error:
          _status = PremiumStatus.error;
          // iOS puede entregar la cancelación del usuario como `error` con un
          // código de cancelación; lo distinguimos del fallo real.
          _emitMessage(
            _isCancellation(purchase.error) ? msgCanceled : msgFailed,
            isError: true,
          );
          // IMPORTANTE: completar también las transacciones en error para que
          // no se reintenten indefinidamente.
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          _status = isPremium ? PremiumStatus.purchased : PremiumStatus.idle;
          _emitMessage(msgCanceled, isError: true);
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // En producción real, aquí se debería verificar el recibo
          // (purchase.verificationData) contra un backend/servidor de licencias.
          // Para este mock local consideramos válida la transacción.
          final valid = await _verifyPurchase(purchase);
          if (valid) {
            await _grantPlan(plan);
            // Solo una restauración (no una compra nueva) muestra el mensaje
            // de "compra restaurada".
            if (purchase.status == PurchaseStatus.restored) {
              _emitMessage(msgRestoreSuccess, isError: false);
            }
          }
          // Completar SIEMPRE: marca la transacción como finalizada en la
          // tienda y evita que quede en el limbo / se reentregue al reabrir.
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
      }
    }
  }

  PremiumPlan _planForProductId(String productId) {
    if (productId == weeklyProductId) return PremiumPlan.weekly;
    if (productId == annualProductId) return PremiumPlan.annual;
    return PremiumPlan.none;
  }

  /// Heurística multiplataforma para distinguir una cancelación del usuario
  /// dentro de un `PurchaseStatus.error`. Android suele emitir
  /// `PurchaseStatus.canceled`, pero iOS/StoreKit puede llegar aquí con un
  /// código de cancelación (`paymentCancelled`, `userCancelled`, …).
  bool _isCancellation(IAPError? error) {
    if (error == null) return false;
    final haystack = '${error.code} ${error.message}'.toLowerCase();
    return haystack.contains('cancel');
  }

  /// Punto único de verificación de una compra.
  ///
  /// Manda el recibo a la Edge Function `verify-purchase`, que lo contrasta
  /// con la API de Google Play. Si el servidor responde, su veredicto y su
  /// fecha de expiración son los que valen ([_grantFromServer]).
  ///
  /// Si NO responde —función sin desplegar, sin credenciales de Play, sin
  /// red— se concede igualmente en local. Es deliberado: negar el acceso a
  /// una compra real porque nuestro backend está caído es un fallo mucho más
  /// grave que conceder de más a quien manipule el cliente, y el próximo
  /// [syncEntitlement] con conexión corrige el estado.
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    if (_planForProductId(purchase.productID) == PremiumPlan.none) return false;

    final service = _entitlements;
    if (service == null) return true;

    // En Android, `serverVerificationData` es el purchaseToken que espera la
    // API de Play Developer.
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) return true;

    final entitlement = await service.verifyPurchase(
      productId: purchase.productID,
      purchaseToken: token,
    );
    if (entitlement == null) return true; // Sin veredicto: se concede local.

    if (entitlement.isActive) {
      await _grantFromServer(entitlement);
    }
    return entitlement.isActive;
  }

  /// Aplica un acceso ya validado por el servidor.
  Future<void> _grantFromServer(Entitlement entitlement) async {
    _serverEntitlement = entitlement;
    _serverVerified = true;
    _plan = _planFromString(entitlement.plan);
    _expiresAt = entitlement.expiresAt;
    _status = PremiumStatus.purchased;
    await _persistState();
    notifyListeners();
  }

  Future<void> _grantPlan(PremiumPlan plan) async {
    // Si el servidor ya concedió este acceso (con SU fecha de expiración), no
    // se pisa con una calculada a partir del reloj del dispositivo.
    if (_serverVerified && _serverEntitlement?.isActive == true) return;

    _plan = plan;
    _expiresAt = DateTime.now()
        .add(plan == PremiumPlan.annual ? _annualDuration : _weeklyDuration);
    _status = PremiumStatus.purchased;
    await _persistState();
    notifyListeners();
  }

  PremiumPlan _planFromString(String? raw) => PremiumPlan.values.firstWhere(
        (p) => p.name == raw,
        orElse: () => PremiumPlan.none,
      );

  DateTime? _readDate(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
