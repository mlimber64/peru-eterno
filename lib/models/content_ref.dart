/// Referencia común y ligera a un contenido navegable (una [EraModel] o un
/// [ContentItem] genérico), usada por las listas mixtas de la UI —Explorar,
/// Favoritos, Historial, "Continuar explorando"— sin necesidad de convertir
/// manualmente entre ambos tipos concretos.
///
/// Este es el "Módulo Descubrimiento". Es deliberadamente independiente del
/// "Módulo Lectura" (`HistoriaArticle`/`HistoriaStage`) — ver la nota de
/// arquitectura al inicio de `data/historia_repository.dart`.
abstract class ContentRef {
  String get id;
  String get category;
  bool get isPremium;
  String? slugForLang(String lang);
  String localizedTitle(String Function(String) t);
  String? localizedSubtitle(String Function(String) t);
}
