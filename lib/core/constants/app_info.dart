/// Datos de identidad de la build, usados en los informes de error para saber
/// a qué versión corresponde un fallo.
///
/// No se usa `package_info_plus` para evitar añadir un plugin nativo solo por
/// leer un número. La contrapartida es que hay que mantenerlo en sincronía con
/// `pubspec.yaml` — y por eso existe `test/app_info_test.dart`, que falla si
/// los dos valores se separan.
class AppInfo {
  const AppInfo._();

  /// Debe coincidir con la parte anterior al `+` de `version:` en pubspec.yaml.
  static const String version = '1.0.0';

  /// Id de la aplicación, el mismo que `applicationId` en build.gradle.kts.
  static const String androidPackage = 'com.perueternno.peru_eterno';

  /// Ficha en Google Play, que se adjunta a todo lo que el usuario comparte.
  ///
  /// La URL se deriva del id de la aplicación, así que ya es la definitiva:
  /// hasta que la app se publique devolverá "no encontrado", pero no hay nada
  /// que cambiar después.
  static const String storeUrl =
      'https://play.google.com/store/apps/details?id=$androidPackage';
}
