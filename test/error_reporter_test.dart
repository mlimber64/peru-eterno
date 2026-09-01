import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peru_eterno/services/error_reporter_service.dart';

// Prueba la parte que de verdad puede fallar en silencio: que los errores se
// capturen y que el filtro de ruido no se coma los distintos ni deje pasar
// una tormenta de repetidos. Sin red ni dispositivo: el envío es inyectable.
/// Traza con el formato real de Dart: el presentador de errores de Flutter
/// parsea cada frame y revienta con cualquier otra cosa.
StackTrace _traza(String funcion) => StackTrace.fromString(
      '#0      $funcion (package:peru_eterno/fake.dart:10:5)\n'
      '#1      otraFuncion (package:peru_eterno/fake.dart:20:7)',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('captura errores de Flutter, ignora repetidos y respeta el tope', () {
    final enviados = <ErrorReport>[];
    final reporter = ErrorReporterService(
      enabled: true, // En test kDebugMode es true; aquí se fuerza.
      sink: (report) async => enviados.add(report),
    );

    final anterior = FlutterError.onError;
    addTearDown(() => FlutterError.onError = anterior);
    reporter.install();

    // 1. Un error del framework se captura y NO se marca como fatal: la app
    //    sobrevive a estos.
    FlutterError.reportError(FlutterErrorDetails(
      exception: StateError('algo se rompió'),
      stack: _traza('primera'),
      library: 'widgets library',
    ));

    expect(enviados, hasLength(1));
    expect(enviados.single.errorType, 'StateError');
    expect(enviados.single.message, contains('algo se rompió'));
    expect(enviados.single.isFatal, isFalse);
    expect(enviados.single.context, isNotNull);

    // 2. El mismo error otra vez (bucle de repintado) no se reenvía.
    for (var i = 0; i < 5; i++) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: StateError('algo se rompió'),
        stack: _traza('primera'),
        library: 'widgets library',
      ));
    }
    expect(enviados, hasLength(1), reason: 'los repetidos no deben reenviarse');

    // 3. Un error DISTINTO sí pasa: el filtro no puede tragarse fallos nuevos.
    FlutterError.reportError(FlutterErrorDetails(
      exception: ArgumentError('otro distinto'),
      stack: _traza('otra'),
    ));
    expect(enviados, hasLength(2));
    expect(enviados.last.errorType, 'ArgumentError');

    // 4. El tope por sesión corta una tormenta de errores únicos.
    for (var i = 0; i < ErrorReporterService.maxReportsPerSession + 10; i++) {
      reporter.report(
        Exception('único $i'),
        _traza('bucle'),
      );
    }
    expect(
      enviados.length,
      ErrorReporterService.maxReportsPerSession,
      reason: 'nunca más informes que el tope de la sesión',
    );
  });
}
