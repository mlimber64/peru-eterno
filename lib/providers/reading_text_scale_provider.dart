import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Factor de escala del texto de lectura (artículos), controlado con el
/// pellizco de dos dedos. Se persiste para aplicarse en todos los artículos.
class ReadingTextScaleProvider extends ChangeNotifier {
  static const String _prefKey = 'reading_text_scale';
  static const double minScale = 0.85;
  static const double maxScale = 2.2;

  double _scale = 1.0;
  double get scale => _scale;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefKey) ?? 1.0;
    _scale = saved.clamp(minScale, maxScale);
  }

  /// Actualiza el factor en vivo durante el pellizco (no persiste).
  void setScale(double value) {
    final clamped = value.clamp(minScale, maxScale);
    if ((clamped - _scale).abs() < 0.001) return;
    _scale = clamped;
    notifyListeners();
  }

  /// Guarda el valor actual al soltar los dedos.
  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefKey, _scale);
  }
}
