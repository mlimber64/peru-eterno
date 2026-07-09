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
    final savedLanguage = prefs.getString(_prefKey) ?? defaultLanguage;
    await _loadLanguage(savedLanguage);
  }

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
