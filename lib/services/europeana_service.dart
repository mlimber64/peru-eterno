import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/europeana_item.dart';

class EuropeanaService {
  static final EuropeanaService _instance = EuropeanaService._();
  static EuropeanaService get instance => _instance;
  EuropeanaService._();

  // Register at: https://pro.europeana.eu/page/apis
  //
  // La clave NO se hardcodea: se inyecta en tiempo de compilación con
  // --dart-define=EUROPEANA_API_KEY=xxxx. Así nunca viaja en el repositorio
  // ni queda visible en el binario como literal de código fuente.
  static const String _apiKey =
      String.fromEnvironment('EUROPEANA_API_KEY');

  /// Indica si la app fue compilada con una clave válida. Si es `false`,
  /// la integración con Europeana se degrada con elegancia (devuelve listas
  /// vacías) en vez de lanzar peticiones que el servidor rechazará.
  static bool get isConfigured => _apiKey.isNotEmpty;

  static const Duration _requestTimeout = Duration(seconds: 15);

  static const Map<String, String> _eraQueries = {
    'caral': 'Caral Peru',
    'moche': 'Moche culture Peru',
    'tiahuanaco': 'Tiwanaku Bolivia',
    'inca': 'Inca Empire Peru',
    'conquista': 'Spanish conquest Peru',
    'virreinato': 'Viceroyalty Peru colonial',
    'independencia': 'Peru independence 1821',
  };

  Future<List<EuropeanaItem>> searchForEra(String eraId) async {
    // Sin clave configurada no tiene sentido contactar la API.
    if (!isConfigured) return [];

    final query = _eraQueries[eraId];
    if (query == null) return [];

    try {
      final url = Uri.https(
        'api.europeana.eu',
        '/record/v2/search.json',
        {
          'wskey': _apiKey,
          'query': query,
          'qf': 'TYPE:IMAGE',
          'reusability': 'open',
          'rows': '5',
          'profile': 'rich',
        },
      );

      final response = await http
          .get(url, headers: {
            'Accept': 'application/json',
            'User-Agent': 'PeruEterno/2.0 (flutter; educational)',
          })
          .timeout(_requestTimeout);

      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final success = body['success'] as bool? ?? false;
      if (!success) return [];

      final items = body['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => _parseItem(e as Map<String, dynamic>))
          .whereType<EuropeanaItem>()
          .where((item) => item.hasImage)
          .toList();
    } catch (_) {
      return [];
    }
  }

  EuropeanaItem? _parseItem(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String? ?? '';

      final titles = json['title'] as List<dynamic>?;
      final dcTitles = json['dcTitle'] as List<dynamic>?;
      final title = (titles?.isNotEmpty == true
              ? titles!.first
              : dcTitles?.isNotEmpty == true
                  ? dcTitles!.first
                  : null) as String? ??
          'Sin título';

      final providers = json['dataProvider'] as List<dynamic>?;
      final institution = providers?.isNotEmpty == true
          ? providers!.first as String
          : 'Institución desconocida';

      final previews = json['edmPreview'] as List<dynamic>?;
      final thumbnailUrl =
          previews?.isNotEmpty == true ? previews!.first as String? : null;

      final fullImages = json['edmIsShownBy'] as List<dynamic>?;
      final fullImageUrl = fullImages?.isNotEmpty == true
          ? fullImages!.first as String?
          : thumbnailUrl;

      final europeanaUrl =
          json['guid'] as String? ?? 'https://www.europeana.eu/item$id';

      return EuropeanaItem(
        id: id,
        title: title,
        institution: institution,
        thumbnailUrl: thumbnailUrl,
        fullImageUrl: fullImageUrl,
        europeanaUrl: europeanaUrl,
      );
    } catch (_) {
      return null;
    }
  }
}
