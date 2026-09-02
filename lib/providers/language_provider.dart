import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/localization_service.dart';

class LanguageProvider extends ChangeNotifier {
  final LocalizationService _localizationService = LocalizationService();

  static const String _prefKey = 'selected_language';
  static const String defaultLanguage = 'it';

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'it', 'label': 'Italiano', 'flag': '🇮🇹'},
    {'code': 'es', 'label': 'Español', 'flag': '🇵🇪'},
    {'code': 'en', 'label': 'English', 'flag': '🇬🇧'},
  ];

  String _currentLanguage = defaultLanguage;
  bool _isLoading = false;

  String get currentLanguage => _currentLanguage;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadLanguage(
      resolveInitialLanguage(
        saved: prefs.getString(_prefKey),
        deviceLocales: PlatformDispatcher.instance.locales
            .map((l) => l.languageCode)
            .toList(),
      ),
    );
  }

  /// Idioma con el que arranca la app.
  ///
  /// Antes se abría SIEMPRE en italiano: alguien que instalaba la app con el
  /// teléfono en español o inglés se encontraba una primera pantalla que no
  /// entendía, y desinstalaba antes de llegar a nada.
  ///
  /// Prioridad:
  ///   1. Lo que el usuario eligió alguna vez ([saved]) — manda siempre, y no
  ///      se pisa aunque después cambie el idioma del sistema.
  ///   2. El primer idioma del dispositivo que la app tenga traducido.
  ///   3. Italiano, el idioma principal del contenido.
  ///
  /// La detección NO se persiste: si el usuario nunca ha elegido, cada
  /// arranque vuelve a mirar el teléfono. Así, cambiar el idioma del sistema
  /// se refleja en la app sin tener que tocar nada.
  @visibleForTesting
  static String resolveInitialLanguage({
    required String? saved,
    required List<String> deviceLocales,
  }) {
    if (saved != null && _isSupported(saved)) return saved;

    for (final code in deviceLocales) {
      if (_isSupported(code)) return code;
    }
    return defaultLanguage;
  }

  static bool _isSupported(String code) =>
      supportedLanguages.any((l) => l['code'] == code);

  Future<void> changeLanguage(String languageCode) async {
    if (languageCode == _currentLanguage) return;
    _isLoading = true;
    notifyListeners();

    await _loadLanguage(languageCode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, languageCode);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    await _localizationService.load(languageCode);
  }

  String t(String key) => _localizationService.translate(key);

  List<String> tList(String key) => _localizationService.translateList(key);
}
