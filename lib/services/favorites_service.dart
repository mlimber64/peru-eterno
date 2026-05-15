import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favorites_v1';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(_key);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('Invalid favorites');
      return decoded.whereType<String>().toSet();
    } catch (_) {
      await prefs.remove(_key);
      return {};
    }
  }

  Future<bool> toggle(String id) async {
    final favorites = await load();
    final wasAdded = favorites.contains(id);
    if (wasAdded) {
      favorites.remove(id);
    } else {
      favorites.add(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(favorites.toList()));
    return !wasAdded; // returns true if now favorited
  }

  Future<bool> isFavorite(String id) async {
    final favorites = await load();
    return favorites.contains(id);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
