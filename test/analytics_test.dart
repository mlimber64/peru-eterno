import 'package:flutter_test/flutter_test.dart';
import 'package:peru_eterno/services/analytics_service.dart';

// La analítica no puede romper la app ni perder eventos en silencio. Se cubren
// las dos formas en que fallaría sin hacer ruido: un `target` que la base
// rechaza (y que tumbaría el lote entero) y el envío por lotes.
void main() {
  group('saneado de identificadores', () {
    test('slug deja los ids con la forma que exige la base', () {
      // Caso real: este capítulo existe y lleva eñe. Sin sanear, su INSERT
      // falla y se lleva por delante los otros nueve eventos del lote.
      expect(AnalyticsEvent.slug('terremoto_tapadas_limeñas'),
          'terremoto_tapadas_limenas');

      // Los ids normales pasan intactos.
      expect(AnalyticsEvent.slug('pp-caral'), 'pp-caral');
      expect(AnalyticsEvent.slug('aji_de_gallina'), 'aji_de_gallina');

      // Mayúsculas y espacios se normalizan.
      expect(AnalyticsEvent.slug('Chan Chan'), 'chan_chan');

      // El check exige empezar por letra o dígito.
      expect(AnalyticsEvent.slug('__raro'), 'raro');

      // Nada que salvar -> null, y la fila va sin `target` en vez de fallar.
      expect(AnalyticsEvent.slug('___'), isNull);
      expect(AnalyticsEvent.slug(null), isNull);

      // Tope de 100.
      expect(AnalyticsEvent.slug('a' * 250)!.length, 100);
    });
  });

  group('envío por lotes', () {
    test('acumula hasta completar el lote y lo manda de una vez', () async {
      final lotes = <List<AnalyticsEvent>>[];
      final analytics = AnalyticsService(
        sessionId: AnalyticsService.newSessionId(),
        enabled: true,
        sink: (batch) async => lotes.add(batch),
      );

      for (var i = 0; i < AnalyticsService.batchSize - 1; i++) {
        analytics.log(AnalyticsService.appOpen);
      }
      // Todavía nada en la red: un INSERT por evento gastaría batería y datos.
      expect(lotes, isEmpty);
      expect(analytics.pendingCount, AnalyticsService.batchSize - 1);

      analytics.log(AnalyticsService.appOpen);
      await Future<void>.delayed(Duration.zero);

      expect(lotes.length, 1);
      expect(lotes.first.length, AnalyticsService.batchSize);
      expect(analytics.pendingCount, 0);
      analytics.dispose();
    });

    test('flush manda lo pendiente y desactivado no registra nada', () async {
      final lotes = <List<AnalyticsEvent>>[];
      final analytics = AnalyticsService(
        sessionId: AnalyticsService.newSessionId(),
        enabled: true,
        sink: (batch) async => lotes.add(batch),
      );
      analytics.log(AnalyticsService.chapterOpen, target: 'pp-caral');
      await analytics.flush();
      expect(lotes.single.single.target, 'pp-caral');

      // Con la analítica apagada (por defecto en debug) no se acumula nada.
      final off = AnalyticsService(
        sessionId: AnalyticsService.newSessionId(),
        enabled: false,
        sink: (batch) async => lotes.add(batch),
      );
      off.log(AnalyticsService.appOpen);
      expect(off.pendingCount, 0);
      off.dispose();
      analytics.dispose();
    });
  });

  test('newSessionId genera un UUID v4 válido', () {
    final id = AnalyticsService.newSessionId();
    expect(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
          .hasMatch(id),
      isTrue,
      reason: 'la columna session_id es de tipo uuid: $id',
    );
    expect(AnalyticsService.newSessionId(), isNot(id));
  });
}
