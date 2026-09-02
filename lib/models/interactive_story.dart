// Modelo de árbol de decisiones para las historias interactivas
// ("Elige tu camino"). Fuente: assets/data-refactor/stories/*.json.
// Mismo patrón trilingüe (es/it/en) que HistoriaArticle/HistoriaStage,
// con fallback a italiano (idioma principal).

/// Una opción de decisión dentro de un [InteractiveStoryNode].
class StoryChoice {
  final Map<String, String> text;
  final String nextNodeId;
  final bool requiredPremium;

  const StoryChoice({
    required this.text,
    required this.nextNodeId,
    this.requiredPremium = false,
  });

  factory StoryChoice.fromJson(Map<String, dynamic> json) {
    return StoryChoice(
      text: _toStringMap(json['text']),
      nextNodeId: json['next_node_id'] as String,
      requiredPremium: json['required_premium'] as bool? ?? false,
    );
  }

  String textFor(String lang) => text[lang] ?? text['it'] ?? '';

  static Map<String, String> _toStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }
}

/// Un nodo (escena) del árbol de decisiones.
class InteractiveStoryNode {
  final String nodeId;
  final Map<String, String> title;
  final Map<String, String> narrative;
  final String? imagePath;
  final Map<String, String>? historicalFact;
  final bool isEnding;
  final List<StoryChoice> choices;

  const InteractiveStoryNode({
    required this.nodeId,
    required this.title,
    required this.narrative,
    this.imagePath,
    this.historicalFact,
    this.isEnding = false,
    this.choices = const [],
  });

  factory InteractiveStoryNode.fromJson(Map<String, dynamic> json) {
    return InteractiveStoryNode(
      nodeId: json['node_id'] as String,
      title: _toStringMap(json['title']),
      narrative: _toStringMap(json['narrative']),
      imagePath: json['image_path'] as String?,
      historicalFact: json['historical_fact'] != null
          ? _toStringMap(json['historical_fact'])
          : null,
      isEnding: json['is_ending'] as bool? ?? false,
      choices: (json['choices'] as List<dynamic>? ?? const [])
          .map((e) => StoryChoice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get hasHistoricalFact =>
      historicalFact != null && historicalFact!.isNotEmpty;

  String titleFor(String lang) => title[lang] ?? title['it'] ?? nodeId;
  String narrativeFor(String lang) => narrative[lang] ?? narrative['it'] ?? '';
  String? historicalFactFor(String lang) =>
      historicalFact?[lang] ?? historicalFact?['it'];

  static Map<String, String> _toStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }
}

/// Una historia interactiva completa: metadatos + todos sus nodos indexados
/// por `node_id` para navegación O(1).
class InteractiveStory {
  final String id;
  final Map<String, String> titulo;
  final Map<String, String> descripcion;
  final String coverImage;
  final bool isPremium;
  final String startNodeId;
  final Map<String, InteractiveStoryNode> nodesById;

  const InteractiveStory({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.coverImage,
    required this.isPremium,
    required this.startNodeId,
    required this.nodesById,
  });

  factory InteractiveStory.fromJson(Map<String, dynamic> json) {
    final nodesList = (json['nodes'] as List<dynamic>? ?? const [])
        .map((e) => InteractiveStoryNode.fromJson(e as Map<String, dynamic>))
        .toList();
    return InteractiveStory(
      id: json['id'] as String,
      titulo: _toStringMap(json['titulo']),
      descripcion: _toStringMap(json['descripcion']),
      coverImage: json['imagen_portada'] as String? ?? '',
      isPremium: json['is_premium'] as bool? ?? false,
      startNodeId: json['start_node_id'] as String,
      nodesById: {for (final n in nodesList) n.nodeId: n},
    );
  }

  String tituloFor(String lang) => titulo[lang] ?? titulo['it'] ?? id;
  String descripcionFor(String lang) =>
      descripcion[lang] ?? descripcion['it'] ?? '';

  /// Nodo por id, o `null` si la referencia no existe (JSON mal formado) —
  /// el provider debe manejar este caso sin lanzar excepciones.
  InteractiveStoryNode? node(String nodeId) => nodesById[nodeId];

  InteractiveStoryNode? get startNode => nodesById[startNodeId];

  /// Cantidad de decisiones del camino más corto entre el inicio y un final,
  /// usada solo como referencia para la barra de progreso. Recorrido en
  /// anchura con un set de nodos visitados para blindarse ante ciclos en el
  /// árbol (hoy no los hay, pero evita un bucle infinito si algún JSON futuro
  /// referenciara un nodo ya visitado). Mínimo `1` para no dividir por cero.
  int get shortestPathToEnding {
    final start = startNodeId;
    if (nodesById[start] == null) return 1;
    final visited = <String>{start};
    final queue = <(String, int)>[(start, 0)];
    var i = 0;
    while (i < queue.length) {
      final (nodeId, depth) = queue[i];
      i++;
      final node = nodesById[nodeId];
      if (node == null) continue;
      if (node.isEnding) return depth == 0 ? 1 : depth;
      for (final choice in node.choices) {
        if (visited.add(choice.nextNodeId)) {
          queue.add((choice.nextNodeId, depth + 1));
        }
      }
    }
    return 1;
  }

  static Map<String, String> _toStringMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }
}
