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
