import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  PremiumProvider({InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  /// IDs de producto tal cual dados de alta en Play Console / App Store
  /// Connect (suscripciones). Deben coincidir EXACTAMENTE.
  static const String weeklyProductId = 'peru_eterno_premium_weekly';
  static const String annualProductId = 'peru_eterno_premium_annual';

  static const _kPlan = 'premium_plan';
  static const _kExpiresAt = 'premium_expires_at';
  static const _kTrialEndsAt = 'premium_trial_ends_at';
  static const _kHasUsedTrial = 'premium_has_used_trial';

  static const Duration _weeklyDuration = Duration(days: 7);
  static const Duration _annualDuration = Duration(days: 365);
  static const Duration _trialDuration = Duration(days: 7);

  // Claves i18n de los mensajes de usuario (resueltas en la UI con `t(...)`).
  // Evitan exponer textos técnicos en inglés de la tienda.
  static const String msgCanceled = 'premium.error_canceled';
  static const String msgFailed = 'premium.error_failed';
  static const String msgUnavailable = 'premium.error_unavailable';
  static const String msgRestoreSuccess = 'premium.restore_success';

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  SharedPreferences? _prefs;

  PremiumPlan _plan = PremiumPlan.none;
  DateTime? _expiresAt;
  DateTime? _trialEndsAt;
  bool _hasUsedTrial = false;

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
  bool get isPremium {
    final now = DateTime.now();
    if (_trialEndsAt != null && now.isBefore(_trialEndsAt!)) return true;
    if (_plan != PremiumPlan.none &&
        _expiresAt != null &&
        now.isBefore(_expiresAt!)) {
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

  /// Inicializa el provider. Llamar una sola vez al arrancar la app.
  Future<void> initialize() async {
    // 1) Estado persistido: el usuario sigue premium aunque esté offline.
    _prefs = await SharedPreferences.getInstance();
    _plan = _planFromString(_prefs?.getString(_kPlan));
    _expiresAt = _readDate(_kExpiresAt);
    _trialEndsAt = _readDate(_kTrialEndsAt);
    _hasUsedTrial = _prefs?.getBool(_kHasUsedTrial) ?? false;
    if (isPremium) _status = PremiumStatus.purchased;
    notifyListeners();

    // 2) Disponibilidad de la tienda.
    _storeAvailable = await _iap.isAvailable();
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

    // 3) Suscripción al stream ANTES de cualquier compra/restauración, para
    //    no perder eventos. Se mantiene viva durante toda la vida de la app.
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object _) {
        // No exponemos el mensaje técnico en inglés: usamos clave i18n.
        _status = PremiumStatus.error;
        _emitMessage(msgFailed, isError: true);
      },
    );

    // 4) Carga de detalles de los productos (semanal + anual).
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final ids = {weeklyProductId, annualProductId};
    final response = await _iap.queryProductDetails(ids);
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
    _hasUsedTrial = true;
    _trialEndsAt = DateTime.now().add(_trialDuration);
    _status = PremiumStatus.purchased;
    notifyListeners();

    final p = _prefs;
    if (p != null) {
      await p.setBool(_kHasUsedTrial, true);
      await p.setString(_kTrialEndsAt, _trialEndsAt!.toIso8601String());
    }
    return true;
  }

  // ── Acciones de compra ─────────────────────────────────────────────────────

  /// Lanza el flujo nativo de compra para [plan]. El resultado llega por el
  /// stream; observa [isPremium] / [status] para reaccionar en la UI.
  ///
  /// Devuelve `true` si el flujo se pudo iniciar; `false` si la tienda o el
  /// producto no están disponibles.
  Future<bool> buyPlan(PremiumPlan plan) async {
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

  /// Punto único de verificación. Reemplazar por validación server-side
  /// (recomendado) cuando exista backend. Hoy acepta la transacción local.
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    return _planForProductId(purchase.productID) != PremiumPlan.none;
  }

  Future<void> _grantPlan(PremiumPlan plan) async {
    _plan = plan;
    _expiresAt = DateTime.now()
        .add(plan == PremiumPlan.annual ? _annualDuration : _weeklyDuration);
    _status = PremiumStatus.purchased;
    final p = _prefs;
    if (p != null) {
      await p.setString(_kPlan, plan.name);
      await p.setString(_kExpiresAt, _expiresAt!.toIso8601String());
    }
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
