class AppConfig {
  AppConfig._();

  /// Controla si se permite el fallback a Wikipedia cuando no hay contenido
  /// editorial local. Cambiar a false para ir 100% offline/editorial.
  static const bool enableWikipediaFallback = true;
}
