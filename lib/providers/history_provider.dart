import 'package:flutter/foundation.dart';
import '../data/content_repository.dart';
import '../data/eras_repository.dart';
import '../models/content_item.dart';
import '../services/history_service.dart';

class HistoryProvider extends ChangeNotifier {
  final _service = HistoryService();
  List<String> _ids = [];

  List<String> get ids => List.unmodifiable(_ids);

  List<ContentItem> get recentItems {
    return _ids.map((id) {
      // Check content repository first
      final item = ContentRepository.findById(id);
      if (item != null) return item;
      // Check eras (as ContentItem)
      try {
        final era = ErasRepository.allEras.firstWhere((e) => e.id == id);
        return ContentItem(
          id: era.id,
          category: 'era',
          wikipediaSlug: era.wikipediaSlug,
          isPremium: era.isPremium,
        );
      } catch (_) {
        return null;
      }
    }).whereType<ContentItem>().take(3).toList();
  }

  Future<void> initialize() async {
    _ids = await _service.load();
    notifyListeners();
  }

  Future<void> add(String id) async {
    await _service.add(id);
    _ids = await _service.load();
    notifyListeners();
  }

  Future<void> clear() async {
    await _service.clear();
    _ids = [];
    notifyListeners();
  }
}
