import 'package:flutter_test/flutter_test.dart';
import 'package:peru_eterno/core/navigation/app_navigation.dart';

// Quién puede leer qué del archivo histórico. Se testea aparte porque la
// regla la comparten tres sitios —la navegación y las dos pantallas que
// pintan el candado— y antes cada uno llevaba su propia copia: al mover el
// límite de pago se quedaban en desacuerdo y la lista marcaba como premium
// capítulos que sí se abrían.
void main() {
  bool bloqueado({
    required bool premium,
    required bool delDia,
    required bool etapaDePago,
  }) =>
      AppNavigation.isHistoriaArticleLocked(
        userIsPremium: premium,
        isDailyArticle: delDia,
        stageIsPremium: etapaDePago,
      );

  test('isHistoriaArticleLocked deja pasar la historia del día y las etapas libres',
      () {
    // Un usuario de pago entra a todo.
    expect(bloqueado(premium: true, delDia: false, etapaDePago: true), isFalse);

    // La Historia del Día es gratis SIEMPRE, aunque caiga en una etapa de
    // pago: es el gancho de la racha, y bloquearla rompería el hábito diario
    // que sostiene toda la retención.
    expect(bloqueado(premium: false, delDia: true, etapaDePago: true), isFalse);

    // Cualquier capítulo de una etapa libre (hoy, Perú prehispánico).
    expect(bloqueado(premium: false, delDia: false, etapaDePago: false), isFalse);

    // El único caso bloqueado: usuario free, capítulo que no es el del día y
    // etapa de pago.
    expect(bloqueado(premium: false, delDia: false, etapaDePago: true), isTrue);
  });
}
