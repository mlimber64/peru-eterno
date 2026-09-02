import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/category_config.dart';
import '../../data/historia_stages_repository.dart';
import '../../models/content_item.dart';
import '../../models/era_model.dart';
import '../../models/historia_article.dart';
import '../../models/historia_stage.dart';
import '../../providers/daily_story_provider.dart';
import '../../providers/premium_provider.dart';
import '../../screens/content_detail_screen.dart';
import '../../screens/era_detail_screen.dart';
import '../../screens/historia_article_detail_screen.dart';
import '../../screens/historia_subtopics_screen.dart';
import '../../screens/premium_screen.dart';
import '../../widgets/coming_soon.dart';

class AppNavigation {
  /// Navigator raíz de la app. Necesario para navegar desde fuera del árbol
  /// de widgets (p. ej. el listener de clic del Home Screen Widget nativo,
  /// que no tiene un `BuildContext` propio). Conectado en `app.dart` vía
  /// `MaterialApp(navigatorKey: ...)`.
  static final navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> openEra(
    BuildContext context,
    EraModel era, {
    bool isLocked = false,
  }) async {
    if (isLocked) {
      return openPremium(context);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EraDetailScreen(era: era)),
    );
  }

  static Future<void> openContent(
    BuildContext context,
    ContentItem item, {
    bool isLocked = false,
  }) async {
    // Red de seguridad centralizada: cubre cualquier punto de entrada
    // (presente o futuro) a categorías bloqueadas como "Próximamente" en
    // esta primera versión, aunque cada pantalla ya evita navegar hasta acá
    // para esas categorías.
    if (CategoryConfigs.isComingSoon(item.category)) {
      showComingSoonSnackBar(context);
      return;
    }
    if (isLocked) {
      return openPremium(context);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ContentDetailScreen(item: item)),
    );
  }

  static Future<void> openPremium(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
  }

  static Future<void> openHistoriaStage(
    BuildContext context,
    HistoriaStage stage,
  ) async {
    // Puerta de la etapa: las de pago ni se abren para un usuario free, así
    // no ve una lista de capítulos que no puede leer.
    if (stage.isPremium && !context.read<PremiumProvider>().isPremium) {
      return openPremium(context);
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HistoriaSubtopicsScreen(
          stage: stage,
          carouselImages:
              HistoriaStagesRepository.carouselImagesForStage(stage.id),
        ),
      ),
    );
  }

  /// Regla ÚNICA de acceso al archivo histórico. Pura a propósito: las
  /// pantallas que pintan un candado y esta clase, que decide si navegar,
  /// tienen que responder lo mismo — antes cada una llevaba su propia copia
  /// de la condición y al mover el límite de pago se quedaban en desacuerdo
  /// (la lista decía "Contenido Premium" en capítulos que sí se abrían).
  ///
  /// Un usuario free puede leer la "Historia del Día" —sea de la etapa que
  /// sea, es el gancho de la racha— y cualquier capítulo de una etapa libre.
  static bool isHistoriaArticleLocked({
    required bool userIsPremium,
    required bool isDailyArticle,
    required bool stageIsPremium,
  }) =>
      !userIsPremium && !isDailyArticle && stageIsPremium;

  static Future<void> openHistoriaArticle(
    BuildContext context, {
    required HistoriaArticle article,
    required List<HistoriaArticle> allArticles,
    HistoriaStage? stage,
    List<String>? carouselImages,
    bool replace = false,
  }) async {
    // Punto único de bloqueo del archivo histórico. Cubre todos los caminos
    // de navegación al lector (home, subtemas, lista prehispánica, álbum de
    // coleccionables, mapa, widget, prev/next y "explora también" dentro del
    // propio lector), que pasan todos por aquí.
    //
    // Un usuario free puede leer: la "Historia del Día" —sea de la etapa que
    // sea, es el gancho de la racha— y cualquier capítulo de una etapa libre
    // ([HistoriaStage.isPremium] == false). Lo demás cae al paywall.
    final isPremium = context.read<PremiumProvider>().isPremium;
    final isDailyArticle =
        context.read<DailyStoryProvider>().dailyArticle?.id == article.id;

    // La etapa se resuelve ANTES de decidir porque hace falta para saber si
    // el capítulo es de pago; da igual el orden para el resto del método.
    final resolvedStage = stage ?? await _resolveStage(article.parentStageId);
    if (!context.mounted) return;

    // Sin etapa conocida se asume de pago: es el lado seguro, y solo pasa si
    // el artículo trae un `parentStageId` roto.
    final locked = isHistoriaArticleLocked(
      userIsPremium: isPremium,
      isDailyArticle: isDailyArticle,
      stageIsPremium: resolvedStage?.isPremium ?? true,
    );
    if (locked) return openPremium(context);

    final route = MaterialPageRoute(
      builder: (_) => HistoriaArticleDetailScreen(
        article: article,
        allArticles: allArticles,
        stage: resolvedStage,
        carouselImages: carouselImages ??
            (resolvedStage != null
                ? HistoriaStagesRepository.carouselImagesForStage(
                    resolvedStage.id,
                  )
                : const []),
      ),
    );

    if (replace) {
      await Navigator.pushReplacement(context, route);
      return;
    }
    await Navigator.push(context, route);
  }

  static Future<HistoriaStage?> _resolveStage(String? stageId) async {
    final id = (stageId == null || stageId.isEmpty || stageId == 'unknown')
        ? 'peru_prehispanico'
        : stageId;
    final stages = await HistoriaStagesRepository.loadStages();
    try {
      return stages.firstWhere((stage) => stage.id == id);
    } catch (_) {
      return null;
    }
  }
}
