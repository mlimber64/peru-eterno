import 'package:flutter_test/flutter_test.dart';
import 'package:peru_eterno/services/review_prompt_service.dart';

// Google solo deja mostrar la hoja de valoración unas pocas veces al año por
// usuario. Si se gasta en mal momento, no vuelve. Por eso la decisión de
// cuándo pedirla merece test propio.
void main() {
  final ahora = DateTime(2026, 9, 1);

  test('shouldAsk solo pide la valoración cuando de verdad toca', () {
    // Pocos momentos buenos: uno puede ser casualidad, todavía no.
    expect(
      ReviewPromptService.shouldAsk(
        goodMoments: 2,
        lastAskedAt: null,
        askedForVersion: null,
        currentVersion: '1.0.0',
        now: ahora,
      ),
      isFalse,
    );

    // Tercer momento bueno y nunca se le pidió: adelante.
    expect(
      ReviewPromptService.shouldAsk(
        goodMoments: 3,
        lastAskedAt: null,
        askedForVersion: null,
        currentVersion: '1.0.0',
        now: ahora,
      ),
      isTrue,
    );

    // Ya se le pidió en esta versión: no se insiste por muchos logros que sume.
    expect(
      ReviewPromptService.shouldAsk(
        goodMoments: 20,
        lastAskedAt: ahora.subtract(const Duration(days: 400)),
        askedForVersion: '1.0.0',
        currentVersion: '1.0.0',
        now: ahora,
      ),
      isFalse,
    );

    // Versión nueva pero hace poco que se le preguntó: sigue siendo pronto.
    expect(
      ReviewPromptService.shouldAsk(
        goodMoments: 10,
        lastAskedAt: ahora.subtract(const Duration(days: 10)),
        askedForVersion: '1.0.0',
        currentVersion: '1.1.0',
        now: ahora,
      ),
      isFalse,
    );

    // Versión nueva y ha pasado tiempo de sobra: se puede volver a pedir.
    expect(
      ReviewPromptService.shouldAsk(
        goodMoments: 10,
        lastAskedAt: ahora.subtract(const Duration(days: 200)),
        askedForVersion: '1.0.0',
        currentVersion: '1.1.0',
        now: ahora,
      ),
      isTrue,
    );
  });
}
