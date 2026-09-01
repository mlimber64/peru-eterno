import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_info.dart';
import 'supabase_auth_service.dart';

/// Un fallo listo para enviar. Solo datos técnicos: ni texto escrito por el
/// usuario, ni su correo, ni qué estaba leyendo.
class ErrorReport {
  final String errorType;
  final String message;
  final String? stackTrace;
  final String? context;
  final bool isFatal;

  const ErrorReport({
    required this.errorType,
    required this.message,
    this.stackTrace,
    this.context,
    required this.isFatal,
  });

  /// Firma para detectar repeticiones. Se queda con las primeras líneas de la
  /// traza: un mismo fallo en un bucle produce trazas idénticas ahí.
  String get signature {
    final head = (stackTrace ?? '').split('\n').take(3).join('|');
    return '$errorType::$message::$head';
  }

  Map<String, dynamic> toRow({
    required String? userId,
    required String locale,
  }) =>
      {
        if (userId != null) 'user_id': userId,
        'app_version': AppInfo.version,
        'platform': _platformName,
        'os_version': _osVersion,
        'locale': locale,
        'error_type': _truncate(errorType, 200),
        'message': _truncate(message, 2000),
        'stack_trace': _truncate(stackTrace ?? '', 8000),
        'context': _truncate(context ?? '', 200),
        'is_fatal': isFatal,
      };

  static String get _platformName {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  static String get _osVersion {
    if (kIsWeb) return '';
    try {
      return _truncate(Platform.operatingSystemVersion, 200);
    } catch (_) {
      return '';
    }
  }

  static String _truncate(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}

/// A dónde va un informe. Inyectable para poder probar la captura sin red ni
/// dispositivo (ver `test/error_reporter_test.dart`).
typedef ErrorSink = Future<void> Function(ErrorReport report);

/// Captura los errores de Dart que hoy pasan desapercibidos y los manda a
/// `app_error_reports`.
///
/// Por qué hace falta: un error de Dart no mata el proceso, así que Android
/// Vitals de Play Console —que sí ve crashes nativos y ANRs sin ningún SDK— no
/// se entera. Sin esto, un fallo en producción solo se descubre si un usuario
/// se molesta en escribir un correo.
///
/// Se engancha a los dos sitios por los que sale un error en Flutter:
///
///   · `FlutterError.onError` — errores del framework (un build que revienta,
///     un layout imposible). La app suele sobrevivir: `is_fatal = false`.
///   · `PlatformDispatcher.instance.onError` — errores asíncronos que nadie
///     capturó. Ahí la app ya está rota: `is_fatal = true`.
///
/// Nunca lanza ni bloquea: si no hay red o la migración no está aplicada, el
/// error se pierde en silencio, que es preferible a que el reportador de
/// errores se convierta en una fuente de errores.
class ErrorReporterService {
  /// Máximo de informes por sesión. Un bucle de repintado puede generar miles
  /// de errores idénticos en segundos; sin tope, la app se dedicaría a subir
  /// informes en vez de a funcionar.
  static const int maxReportsPerSession = 25;

  /// Ventana en la que un fallo con la misma firma se considera repetido.
  static const Duration duplicateWindow = Duration(minutes: 5);

  final ErrorSink _sink;

  /// `false` en debug por defecto: los errores de desarrollo ya se ven en
  /// consola y no tiene sentido ensuciar la tabla con ellos.
  final bool enabled;

  final Map<String, DateTime> _recentSignatures = {};
  int _sentThisSession = 0;

  ErrorReporterService({required ErrorSink sink, bool? enabled})
      : _sink = sink,
        enabled = enabled ?? !kDebugMode;

  /// Construye el reportador que escribe en Supabase.
  ///
  /// Si `client` es `null` (app compilada sin Supabase), el sink es un no-op:
  /// la app sigue funcionando exactamente igual.
  factory ErrorReporterService.supabase({
    required SupabaseClient? client,
    required SupabaseAuthService auth,
    required String Function() localeProvider,
    bool? enabled,
  }) {
    return ErrorReporterService(
      enabled: enabled,
      sink: (report) async {
        if (client == null) return;
        try {
          await client.from('app_error_reports').insert(
                report.toRow(
                  userId: auth.userId.value,
                  locale: localeProvider(),
                ),
              );
        } catch (_) {
          // Sin red, tabla inexistente, RLS… se descarta. Un fallo al
          // reportar un fallo no puede propagarse.
        }
      },
    );
  }

  /// Engancha los manejadores globales. Llamar una sola vez, antes de
  /// `runApp`.
  void install() {
    final previousFlutterOnError = FlutterError.onError;

    FlutterError.onError = (details) {
      // Se conserva el comportamiento anterior (en debug, pinta el error en
      // rojo en consola) además de reportarlo.
      previousFlutterOnError?.call(details);
      report(
        details.exception,
        details.stack,
        context: details.context?.toString() ?? details.library,
        isFatal: false,
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, isFatal: true);
      return true; // Tratado: evita que el error suba y mate el isolate.
    };
  }

  /// Registra un error. Se puede llamar a mano desde un `catch` para dejar
  /// constancia de algo que se manejó pero no debería pasar.
  void report(
    Object error,
    StackTrace? stack, {
    String? context,
    bool isFatal = false,
  }) {
    if (!enabled) return;

    final report = ErrorReport(
      errorType: error.runtimeType.toString(),
      message: error.toString(),
      stackTrace: stack?.toString(),
      context: context,
      isFatal: isFatal,
    );

    if (!_shouldSend(report)) return;

    _sentThisSession++;
    unawaited(_sink(report));
  }

  /// Filtra ruido: tope por sesión y repeticiones dentro de [duplicateWindow].
  bool _shouldSend(ErrorReport report) {
    if (_sentThisSession >= maxReportsPerSession) return false;

    final now = DateTime.now();
    final lastSeen = _recentSignatures[report.signature];
    if (lastSeen != null && now.difference(lastSeen) < duplicateWindow) {
      return false;
    }
    _recentSignatures[report.signature] = now;

    // El mapa no puede crecer sin límite en una sesión larga.
    if (_recentSignatures.length > 100) {
      final oldest = _recentSignatures.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (final entry in oldest.take(50)) {
        _recentSignatures.remove(entry.key);
      }
    }
    return true;
  }

  /// Informes enviados en esta sesión (para tests y diagnóstico).
  @visibleForTesting
  int get sentThisSession => _sentThisSession;
}
