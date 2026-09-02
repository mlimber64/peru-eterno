import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../core/navigation/app_navigation.dart';
import '../models/historia_article.dart';
import '../providers/daily_story_provider.dart';

/// Sincroniza la Historia del Día con el Home Screen Widget nativo
/// (Android; bases dejadas para iOS, ver `ios/HOME_WIDGET_SETUP.md`) y
/// gestiona la apertura de la app cuando el usuario toca el widget.
///
/// Todas las llamadas a `home_widget` están protegidas: en plataformas sin
/// implementación nativa (Windows, Linux, macOS, web — este proyecto compila
/// para escritorio) el plugin no debe tirar una excepción no capturada.
class HomeWidgetService {
  static const String _appGroupId = 'group.com.perueternno.peru_eterno';
  static const String _androidWidgetName = 'DailyFactWidgetProvider';
  // Debe coincidir con el "kind"/nombre del target de WidgetKit una vez
  // creado en Xcode — ver ios/HOME_WIDGET_SETUP.md. No-op en Android.
  static const String _iosWidgetName = 'DailyFactWidget';

  static const String _kTitle = 'daily_title';
  static const String _kCalloutHeader = 'daily_callout_header';
  static const String _kCalloutBody = 'daily_callout_body';

  static const String _launchUri = 'peruEterno://dailyStory';

  static bool _clickHandlingReady = false;

  /// Publica el título y el dato "¿Sabías qué?" de la Historia del Día en el
  /// widget nativo. Se llama desde [DailyStoryProvider] cada vez que
  /// recalcula la historia del día (arranque de la app o cambio de día).
  static Future<void> updateData(HistoriaArticle article, String lang) async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);

      final callout = article.calloutFor(lang);
      await HomeWidget.saveWidgetData<String>(_kTitle, article.tituloFor(lang));
      await HomeWidget.saveWidgetData<String>(
        _kCalloutHeader,
        callout?.header ?? article.categoriaFor(lang),
      );
      await HomeWidget.saveWidgetData<String>(
        _kCalloutBody,
        callout?.body ?? article.subtituloFor(lang),
      );

      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iosWidgetName,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('HomeWidgetService.updateData: $e');
    }
  }

  /// Registra el manejo del clic sobre el widget: tanto si la app ya estaba
  /// corriendo (stream) como si el widget la abrió en frío
  /// (`initiallyLaunchedFromHomeWidget`). Llamar una sola vez al arrancar.
  static Future<void> initialize({
    required GlobalKey<NavigatorState> navigatorKey,
    required DailyStoryProvider dailyStoryProvider,
  }) async {
    if (_clickHandlingReady) return;
    _clickHandlingReady = true;

    try {
      HomeWidget.widgetClicked.listen(
        (uri) => _handleClick(uri, navigatorKey, dailyStoryProvider),
      );

      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      await _handleClick(initialUri, navigatorKey, dailyStoryProvider);
    } catch (e) {
      if (kDebugMode) debugPrint('HomeWidgetService.initialize: $e');
    }
  }

  static Future<void> _handleClick(
    Uri? uri,
    GlobalKey<NavigatorState> navigatorKey,
    DailyStoryProvider dailyStoryProvider,
  ) async {
    if (uri == null || uri.toString() != _launchUri) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      final article = dailyStoryProvider.dailyArticle;
      if (context == null || article == null) return;
      AppNavigation.openHistoriaArticle(
        context,
        article: article,
        allArticles: dailyStoryProvider.dailyStageArticles,
        stage: dailyStoryProvider.dailyStage,
      );
    });
  }
}
