import 'package:flutter_test/flutter_test.dart';
import 'package:peru_eterno/providers/premium_provider.dart';
import 'package:peru_eterno/services/entitlement_service.dart';

// Cubre la regla que decide quién tiene acceso de pago. Los dos errores
// posibles cuestan dinero en direcciones opuestas: dejar sin premium a quien
// pagó (porque el servidor no contestó) o regalarlo a quien manipuló su
// dispositivo. Un solo `test` por archivo, sin widgets: lógica pura.
void main() {
  final ahora = DateTime(2026, 9, 1, 12, 0);
  final futuro = ahora.add(const Duration(days: 3));
  final pasado = ahora.subtract(const Duration(days: 3));

  Entitlement entitlement({required bool activo, DateTime? expira}) =>
      Entitlement(
        plan: 'weekly',
        expiresAt: expira,
        trialUsed: false,
        isActive: activo,
      );

  test('resolveIsPremium respeta al servidor sin castigar a quien pagó', () {
    // 1. El servidor concede: manda él, aunque en local esté todo vencido.
    expect(
      PremiumProvider.resolveIsPremium(
        server: entitlement(activo: true, expira: futuro),
        serverVerified: true,
        now: ahora,
        trialEndsAt: null,
        plan: PremiumPlan.none,
        expiresAt: null,
      ),
      isTrue,
    );

    // 2. El servidor revoca un acceso que él mismo concedió (suscripción
    //    cancelada): se corta, aunque el estado local siga diciendo que sí.
    expect(
      PremiumProvider.resolveIsPremium(
        server: entitlement(activo: false, expira: pasado),
        serverVerified: true,
        now: ahora,
        trialEndsAt: null,
        plan: PremiumPlan.annual,
        expiresAt: futuro,
      ),
      isFalse,
    );

    // 3. El servidor no reconoce un acceso que NUNCA validó (p. ej. la Edge
    //    Function todavía no está desplegada): no puede revocarlo. Manda lo
    //    local, que es el comportamiento que la app ya tenía.
    expect(
      PremiumProvider.resolveIsPremium(
        server: entitlement(activo: false, expira: null),
        serverVerified: false,
        now: ahora,
        trialEndsAt: null,
        plan: PremiumPlan.annual,
        expiresAt: futuro,
      ),
      isTrue,
    );

    // 4. Sin respuesta del servidor (sin red): decide lo local. Un usuario que
    //    pagó no puede quedarse fuera por abrir la app en el metro.
    expect(
      PremiumProvider.resolveIsPremium(
        server: null,
        serverVerified: true,
        now: ahora,
        trialEndsAt: null,
        plan: PremiumPlan.weekly,
        expiresAt: futuro,
      ),
      isTrue,
    );

    // 5. Sin nada por ningún lado: no hay premium.
    expect(
      PremiumProvider.resolveIsPremium(
        server: null,
        serverVerified: false,
        now: ahora,
        trialEndsAt: pasado,
        plan: PremiumPlan.none,
        expiresAt: null,
      ),
      isFalse,
    );

    // 6. Prueba gratuita local todavía vigente.
    expect(
      PremiumProvider.resolveIsPremium(
        server: null,
        serverVerified: false,
        now: ahora,
        trialEndsAt: futuro,
        plan: PremiumPlan.none,
        expiresAt: null,
      ),
      isTrue,
    );
  });
}
