import 'package:flutter/foundation.dart';
import '../services/favorites_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final _service = FavoritesService();
  Set<String> _favorites = {};

  Set<String> get favorites => Set.unmodifiable(_favorites);

  Future<void> initialize() async {
    _favorites = await _service.load();
    notifyListeners();
  }

  bool isFavorite(String id) => _favorites.contains(id);

  /// Vacía la lista de guardados de una vez. Existía solo el borrado uno a
  /// uno (bucle de `toggle` en Ajustes), que no sirve para "Borrar mis
  /// datos": son N escrituras a disco y deja la lista a medias si falla.
  Future<void> clearAll() async {
    await _service.clear();
    _favorites = {};
    notifyListeners();
  }

  Future<void> toggle(String id) async {
    final nowFavorited = await _service.toggle(id);
    if (nowFavorited) {
      _favorites.add(id);
    } else {
      _favorites.remove(id);
    }
    notifyListeners();
  }
}
