import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peru_eterno/core/constants/app_info.dart';

// AppInfo.version se escribe a mano para no añadir un plugin nativo solo por
// leer un número. Este test es lo que evita que se quede atrás: si se sube la
// versión en pubspec.yaml y se olvida la constante, todos los informes de
// error de la versión nueva llegarían etiquetados con la vieja — y se
// perseguiría un fallo en el sitio equivocado.
void main() {
  test('AppInfo.version coincide con pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
        .firstMatch(pubspec);

    expect(match, isNotNull, reason: 'no se encontró `version:` en pubspec.yaml');
    expect(
      AppInfo.version,
      match!.group(1),
      reason: 'actualiza AppInfo.version en lib/core/constants/app_info.dart',
    );
  });
}
