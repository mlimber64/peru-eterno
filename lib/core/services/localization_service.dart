import 'dart:convert';
import 'package:flutter/services.dart';

class LocalizationService {
  Map<String, dynamic> _strings = {};
  String _currentLanguage = 'it';

  String get currentLanguage => _currentLanguage;

  Future<void> load(String languageCode) async {
    _currentLanguage = languageCode;
    try {
      final jsonString = await rootBundle.loadString('assets/i18n/$languageCode.json');
      _strings = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      if (languageCode != 'it') {
        await load('it');
      }
    }
  }

  String translate(String key) {
    final keys = key.split('.');
    dynamic value = _strings;
    for (final k in keys) {
      if (value is Map<String, dynamic>) {
        value = value[k];
      } else {
        return key;
      }
    }
    return value?.toString() ?? key;
  }

  List<String> translateList(String key) {
    final keys = key.split('.');
    dynamic value = _strings;
    for (final k in keys) {
      if (value is Map<String, dynamic>) {
        value = value[k];
      } else {
        return [];
      }
    }
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}
