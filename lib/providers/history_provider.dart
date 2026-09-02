import 'package:flutter/foundation.dart';
import '../data/content_repository.dart';
import '../data/eras_repository.dart';
import '../models/content_ref.dart';
import '../models/era_model.dart';
import '../services/history_service.dart';

class HistoryProvider extends ChangeNotifier {
  final _service = HistoryService();
  List<String> _ids = [];

  List<String> get ids => List.unmodifiable(_ids);

  List<ContentRef> get recentItems {
    return _ids.map<ContentRef?>((id) {
      // Eras primero (lista corta, y así el resultado es el EraModel real,
      // no una copia genérica): el resto de categorías no comparte ids.
      final era = ErasRepository.allEras
          .cast<EraModel?>()
          .firstWhere((e) => e?.id == id, orElse: () => null);
      if (era != null) return era;
      return ContentRepository.findById(id);
    }).whereType<ContentRef>().take(3).toList();
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
