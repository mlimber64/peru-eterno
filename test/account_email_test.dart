import 'package:flutter_test/flutter_test.dart';
import 'package:peru_eterno/screens/account_screen.dart';

// Un solo `test` por archivo y sin `testWidgets`: montar widgets que tocan
// SharedPreferences o assets se cuelga en este entorno (ver memoria de
// sesión). Esta es lógica pura, así que corre instantánea.
//
// Vale la pena cubrirla porque el envío de códigos está limitado por hora en
// Supabase: cada correo mal formado que dejemos pasar quema un envío real y
// deja al usuario sin poder reintentar.
void main() {
  test('isPlausibleEmail acepta direcciones normales y rechaza las rotas', () {
    const validas = [
      'hola@ejemplo.com',
      'nombre.apellido@sub.dominio.it',
      'a@b.co',
      '  con.espacios.alrededor@ejemplo.com  ',
    ];
    for (final email in validas) {
      expect(isPlausibleEmail(email), isTrue, reason: email);
    }

    const invalidas = [
      '',
      '   ',
      'sinarroba.com',
      '@ejemplo.com',
      'hola@',
      'hola@sindominio',
      'hola@.com',
      'hola@ejemplo.',
      'hola@ejemplo..com',
      'dos@arrobas@ejemplo.com',
      'con espacio@ejemplo.com',
    ];
    for (final email in invalidas) {
      expect(isPlausibleEmail(email), isFalse, reason: email);
    }
  });
}
