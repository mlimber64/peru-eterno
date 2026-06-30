import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado de la compra premium (desbloqueo único, no consumible).
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

/// Gestiona el desbloqueo premium mediante **In-App Purchase** real
/// (Google Play / App Store) usando el plugin oficial `in_app_purchase`.
///
/// Flujo:
/// 1. [initialize] carga el estado persistido, comprueba disponibilidad de la
///    tienda, se suscribe al `purchaseStream` y consulta el producto.
/// 2. [buyPremium] lanza el flujo nativo de compra.
/// 3. El resultado llega **siempre** de forma asíncrona por el stream y se
///    procesa en [_onPurchaseUpdated], que verifica, persiste y **completa**
///    cada transacción ([InAppPurchase.completePurchase]) para que no quede
///    en el limbo.
/// 4. [restorePurchases] re-emite las compras previas por el mismo stream.
class PremiumProvider extends ChangeNotifier {
  PremiumProvider({InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  /// ID del producto tal cual está dado de alta en Play Console / App Store
  /// Connect. Debe coincidir EXACTAMENTE.
  static const String productId = 'peru_eterno_premium';

  static const String _prefKey = 'is_premium';

  // Claves i18n de los mensajes de usuario (resueltas en la UI con `t(...)`).
  // Evitan exponer textos técnicos en inglés de la tienda.
  static const String msgCanceled = 'premium.error_canceled';
  static const String msgFailed = 'premium.error_failed';
  static const String msgUnavailable = 'premium.error_unavailable';
  static const String msgRestoreSuccess = 'premium.restore_success';

  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isPremium = false;
  bool _storeAvailable = false;
  ProductDetails? _product;
  PremiumStatus _status = PremiumStatus.idle;

  // Mensaje de un solo uso para la UI: una clave i18n (error o éxito) que la
  // pantalla muestra una vez y luego limpia con [consumeMessage].
  String? _messageKey;
  bool _messageIsError = false;

  // ── Getters públicos ───────────────────────────────────────────────────────

  /// `true` si el usuario tiene el contenido premium desbloqueado.
  bool get isPremium => _isPremium;

  /// `true` si la tienda (Play/App Store) está disponible en el dispositivo.
  bool get storeAvailable => _storeAvailable;

  /// Detalles del producto (precio localizado, título…) o `null` si no cargó.
  ProductDetails? get product => _product;

  /// Precio formateado por la tienda (ej. "2,99 €"). `null` si no disponible.
  String? get localizedPrice => _product?.price;

  PremiumStatus get status => _status;
  bool get isPurchasePending => _status == PremiumStatus.pending;

  /// Clave i18n del último mensaje a mostrar (error o éxito), o `null` si no
  /// hay nada pendiente. Resolver en la UI con `t(...)`.
  String? get lastError => _messageKey;

  /// `true` si [lastError] representa un error (vs. un mensaje de éxito como
  /// la restauración correcta). Útil para colorear el SnackBar.
  bool get messageIsError => _messageIsError;

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
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_prefKey) ?? false;
    if (_isPremium) _status = PremiumStatus.purchased;
    notifyListeners();

    // 2) Disponibilidad de la tienda.
    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      // Solo avisamos si el usuario aún NO es premium: a quien ya compró no
      // tiene sentido molestarlo con un error de tienda al abrir sin conexión.
      if (!_isPremium) {
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

    // 4) Carga de detalles del producto.
    await _loadProduct();
  }

  Future<void> _loadProduct() async {
    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isNotEmpty) {
      _product = response.productDetails.first;
    } else if (kDebugMode) {
      debugPrint(
        'IAP: producto "$productId" no encontrado. '
        'IDs no resueltos: ${response.notFoundIDs}',
      );
    }
    notifyListeners();
  }

  // ── Acciones de compra ─────────────────────────────────────────────────────

  /// Lanza el flujo nativo de compra. El resultado llega por el stream;
  /// observa [isPremium] / [status] para reaccionar en la UI.
  ///
  /// Devuelve `true` si el flujo se pudo iniciar; `false` si la tienda o el
  /// producto no están disponibles.
  Future<bool> buyPremium() async {
    if (!_storeAvailable || _product == null) {
      _status = PremiumStatus.error;
      _emitMessage(msgUnavailable, isError: true);
      return false;
    }

    _status = PremiumStatus.pending;
    consumeMessage(); // limpia cualquier mensaje previo antes del nuevo intento
    notifyListeners();

    final purchaseParam = PurchaseParam(productDetails: _product!);
    // Producto NO consumible: se compra una vez y queda asociado a la cuenta.
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
      if (purchase.productID != productId) {
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
          _status = _isPremium ? PremiumStatus.purchased : PremiumStatus.idle;
          _emitMessage(msgCanceled, isError: true);
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // En producción real, aquí se debería verificar el recibo
          // (purchase.verificationData) contra un backend/servidor de licencias.
          // Para un desbloqueo único local consideramos válida la transacción.
          final valid = await _verifyPurchase(purchase);
          if (valid) {
            await _grantPremium();
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

  /// Heurística multiplataforma para distinguir una cancelación del usuario
  /// dentro de un `PurchaseStatus.error`. Android suele emitir
  /// `PurchaseStatus.canceled`, pero iOS/StoreKit puede llegar aquí con un
  /// código de cancelación (`paymentCancelled`, `userCancelled`, …).
  bool _isCancellation(IAPError? error) {
    if (error == null) return false;
    final haystack =
        '${error.code} ${error.message}'.toLowerCase();
    return haystack.contains('cancel');
  }

  /// Punto único de verificación. Reemplazar por validación server-side
  /// (recomendado) cuando exista backend. Hoy acepta la transacción local.
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    return purchase.productID == productId;
  }

  Future<void> _grantPremium() async {
    _isPremium = true;
    _status = PremiumStatus.purchased;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
