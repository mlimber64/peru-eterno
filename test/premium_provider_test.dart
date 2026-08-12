import 'package:flutter_test/flutter_test.dart';
import 'package:peru_eterno/providers/premium_provider.dart';

// Pruebas de la lógica pura de la prueba gratuita: no llaman a `initialize()`
// (evita depender de SharedPreferences), así que corren rápido y sin
// colgarse — a diferencia de un testWidgets que monte la app completa (ver
// memoria de sesión: eso se cuelga en Windows en este entorno). Cubren la
// pieza más sensible del negocio: sin esto mal, un usuario podría quedar sin
// acceso premium que pagó, o con acceso gratis que no debería tener.
void main() {
  // El constructor de PremiumProvider toca InAppPurchase.instance (registra
  // el canal de plataforma), lo que requiere el binding de Flutter
  // inicializado aunque el test no monte ningún widget.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PremiumProvider.startFreeTrial', () {
    test('activa 7 días de premium la primera vez', () async {
      final provider = PremiumProvider();
      expect(provider.isPremium, isFalse);
      expect(provider.hasUsedTrial, isFalse);

      final started = await provider.startFreeTrial();

      expect(started, isTrue);
      expect(provider.isPremium, isTrue);
      expect(provider.isInTrial, isTrue);
      expect(provider.hasUsedTrial, isTrue);
      expect(provider.daysLeftInTrial, inInclusiveRange(6, 7));
    });

    test('no se puede activar una segunda vez', () async {
      final provider = PremiumProvider();
      await provider.startFreeTrial();

      final startedAgain = await provider.startFreeTrial();

      expect(startedAgain, isFalse);
    });
  });

  group('PremiumProvider.isPremium', () {
    test('es falso antes de comprar o iniciar la prueba', () {
      final provider = PremiumProvider();
      expect(provider.isPremium, isFalse);
      expect(provider.currentPlan, PremiumPlan.none);
    });
  });
}
