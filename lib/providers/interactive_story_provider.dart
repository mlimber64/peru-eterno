import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/interactive_story_repository.dart';
import '../models/interactive_story.dart';

/// Motor de navegación de las historias interactivas ("Elige tu camino"):
/// carga el árbol de decisiones de una historia, mantiene el nodo actual y
/// el historial del camino recorrido, y persiste el progreso en curso y los
/// finales desbloqueados en [SharedPreferences] (una entrada por historia,
/// indexada por `story.id`).
///
/// Flujo de una decisión: el usuario elige una [StoryChoice] desde el nodo
/// actual. Si ese nodo trae un dato histórico (`historical_fact`), primero
/// se revela (ver [isShowingFact]/[confirmFact]) y solo al confirmar se
/// avanza al siguiente nodo — así el "Dato Real" siempre aparece justo
/// después de tomar la decisión a la que corresponde.
class InteractiveStoryProvider extends ChangeNotifier {
  static const _kProgressPrefix = 'isp_progress_';
  static const _kPathPrefix = 'isp_path_';
  static const _kUnlockedEndingsPrefix = 'isp_endings_';

  SharedPreferences? _prefs;

  InteractiveStory? _story;
  InteractiveStoryNode? _currentNode;
  final List<String> _path = [];
  Set<String> _unlockedEndings = {};

  /// Elección pendiente de confirmación: no-`null` mientras se muestra el
  /// dato histórico del nodo actual, antes de avanzar al nodo elegido.
  StoryChoice? _pendingChoice;

  /// `true` justo después de desbloquear un final por primera vez — bandera
  /// de un solo uso para que la UI muestre el festejo (mismo patrón que
  /// `CollectiblesProvider.unlockCard` / `DailyStoryProvider` streak freeze).
  bool _justUnlockedEnding = false;
  bool get justUnlockedEnding => _justUnlockedEnding;
  void consumeJustUnlockedEndingFlag() => _justUnlockedEnding = false;

  InteractiveStory? get story => _story;
  InteractiveStoryNode? get currentNode => _currentNode;
  List<String> get path => List.unmodifiable(_path);
  bool get isShowingFact => _pendingChoice != null;
  StoryChoice? get pendingChoice => _pendingChoice;

  bool isEndingUnlocked(String nodeId) => _unlockedEndings.contains(nodeId);
  int get unlockedEndingsCount => _unlockedEndings.length;

  /// Carga [storyId] y posiciona el nodo actual: retoma el progreso guardado
  /// si existe y sigue siendo válido (el nodo aún existe y no es un final ya
  /// alcanzado), o arranca desde `start_node_id` en caso contrario.
  Future<void> loadStory(String storyId) async {
    _prefs ??= await SharedPreferences.getInstance();
    final story = await InteractiveStoryRepository.loadStory(storyId);
    if (story == null || story.startNode == null) return;

    _story = story;
    _pendingChoice = null;
    _path.clear();
    _unlockedEndings =
        (_prefs!.getStringList('$_kUnlockedEndingsPrefix$storyId') ??
                const [])
            .toSet();

    final savedNodeId = _prefs!.getString('$_kProgressPrefix$storyId');
    final savedNode = savedNodeId != null ? story.node(savedNodeId) : null;

    if (savedNode != null && savedNodeId != null && !savedNode.isEnding) {
      _currentNode = savedNode;
      final savedPathRaw = _prefs!.getString('$_kPathPrefix$storyId');
      final restoredPath = _decodePath(savedPathRaw);
      _path.addAll(restoredPath.isNotEmpty ? restoredPath : <String>[savedNodeId]);
    } else {
      _currentNode = story.startNode;
      _path.add(story.startNodeId);
    }
    notifyListeners();
  }

  List<String> _decodePath(String? raw) {
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  /// El usuario elige [choice] desde el nodo actual.
  void selectChoice(StoryChoice choice) {
    final node = _currentNode;
    if (node == null || isShowingFact) return;
    if (node.hasHistoricalFact) {
      _pendingChoice = choice;
      notifyListeners();
    } else {
      _advance(choice.nextNodeId);
    }
  }

  /// La UI llama a esto tras mostrar el "Dato Real" del nodo actual, para
  /// avanzar al nodo de la elección pendiente.
  void confirmFact() {
    final choice = _pendingChoice;
    if (choice == null) return;
    _pendingChoice = null;
    _advance(choice.nextNodeId);
  }

  void _advance(String nextNodeId) {
    final story = _story;
    if (story == null) return;
    final next = story.node(nextNodeId);
    // Referencia rota en el JSON (next_node_id sin nodo correspondiente):
    // no avanzamos para no dejar la UI en un estado nulo.
    if (next == null) {
      notifyListeners();
      return;
    }
    _currentNode = next;
    _path.add(nextNodeId);
    notifyListeners();

    if (next.isEnding) {
      unawaited(_unlockEnding(next.nodeId));
    } else {
      unawaited(_saveProgress());
    }
  }

  Future<void> _unlockEnding(String nodeId) async {
    if (!_unlockedEndings.contains(nodeId)) {
      _unlockedEndings.add(nodeId);
      _justUnlockedEnding = true;
      notifyListeners();
    }
    final p = _prefs;
    final story = _story;
    if (p == null || story == null) return;
    await p.setStringList(
      '$_kUnlockedEndingsPrefix${story.id}',
      _unlockedEndings.toList(),
    );
    // Llegar a un final cierra la partida en curso: se limpia el progreso
    // "en curso" para que la próxima apertura arranque desde el inicio.
    await p.remove('$_kProgressPrefix${story.id}');
    await p.remove('$_kPathPrefix${story.id}');
  }

  Future<void> _saveProgress() async {
    final p = _prefs;
    final story = _story;
    final node = _currentNode;
    if (p == null || story == null || node == null) return;
    await p.setString('$_kProgressPrefix${story.id}', node.nodeId);
    await p.setString('$_kPathPrefix${story.id}', jsonEncode(_path));
  }

  /// Reinicia la historia actual desde `start_node_id`.
  Future<void> restart() async {
    final story = _story;
    if (story == null || story.startNode == null) return;
    _pendingChoice = null;
    _path
      ..clear()
      ..add(story.startNodeId);
    _currentNode = story.startNode;
    notifyListeners();

    final p = _prefs;
    if (p != null) {
      await p.remove('$_kProgressPrefix${story.id}');
      await p.remove('$_kPathPrefix${story.id}');
    }
  }
}
