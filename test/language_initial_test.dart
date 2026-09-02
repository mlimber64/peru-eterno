import 'package:flutter_test/flutter_test.dart';
import 'package:peru_eterno/providers/language_provider.dart';

// El idioma de arranque decide si un usuario nuevo entiende la primera
// pantalla o desinstala. Merece test propio, y como es una función pura no
// necesita ni dispositivo ni SharedPreferences.
void main() {
  test('resolveInitialLanguage elige bien el idioma de arranque', () {
    // La elección del usuario manda siempre, aunque el teléfono esté en otro
    // idioma: si eligió inglés a propósito, no se le devuelve a español.
    expect(
      LanguageProvider.resolveInitialLanguage(
        saved: 'en',
        deviceLocales: const ['es', 'it'],
      ),
      'en',
    );

    // Sin elección previa, se usa el idioma del teléfono si está traducido.
    expect(
      LanguageProvider.resolveInitialLanguage(
        saved: null,
        deviceLocales: const ['es'],
      ),
      'es',
    );

    // Con varios idiomas configurados en el sistema, gana el primero que la
    // app tenga traducido — no el primero a secas.
    expect(
      LanguageProvider.resolveInitialLanguage(
        saved: null,
        deviceLocales: const ['fr', 'de', 'en'],
      ),
      'en',
    );

    // Idioma no soportado: italiano, que es el principal del contenido.
    expect(
      LanguageProvider.resolveInitialLanguage(
        saved: null,
        deviceLocales: const ['fr', 'de'],
      ),
      LanguageProvider.defaultLanguage,
    );

    // Sin nada de información tampoco puede quedarse en blanco.
    expect(
      LanguageProvider.resolveInitialLanguage(
        saved: null,
        deviceLocales: const [],
      ),
      LanguageProvider.defaultLanguage,
    );

    // Un valor guardado corrupto o de una versión vieja no debe colar: se
    // trata como si no hubiera elección.
    expect(
      LanguageProvider.resolveInitialLanguage(
        saved: 'pt',
        deviceLocales: const ['en'],
      ),
      'en',
    );
  });
}
