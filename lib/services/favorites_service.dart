import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favorites_v1';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final list = (jsonDecode(raw) as List).cast<String>();
    return list.toSet();
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
