import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {
  static const _key = 'history_v1';
  static const _maxItems = 10;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  Future<void> add(String id) async {
    final history = await load();
    history.remove(id); // remove duplicate if exists
    history.insert(0, id); // most recent first
    final trimmed = history.take(_maxItems).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(trimmed));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
