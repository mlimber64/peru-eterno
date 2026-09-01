import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/content_repository.dart';
import '../../data/historia_stages_repository.dart';
import '../../data/interactive_story_repository.dart';
import '../../models/historia_article.dart';
import '../../models/historia_stage.dart';
import '../../providers/daily_story_provider.dart';
import '../../providers/premium_provider.dart';
import '../../screens/content_detail_screen.dart';
import '../../screens/explore_screen.dart';
import '../../screens/favorites_screen.dart';
import '../../screens/historia_article_detail_screen.dart';
import '../../screens/home_screen.dart';
import '../../screens/interactive_story_screen.dart';
import '../../screens/main_screen.dart';
import '../../screens/map_timeline_screen.dart';
import '../../screens/onboarding_screen.dart';
import '../../screens/premium_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/splash_screen.dart';
import '../../widgets/app_state_views.dart';
import '../constants/category_config.dart';
import 'app_navigation.dart';

/// Router declarativo — integración HÍBRIDA con el sistema de navegación
/// imperativo existente (ver `app_navigation.dart`):
///
///  - `go_router` gestiona el shell de las 5 pestañas (`StatefulShellRoute`,
///    preserva el stack de navegación propio de cada pestaña) y 4 rutas
///    secundarias deep-linkeables (`/historia/:stageId/:articleId`,
///    `/content/:id`, `/interactive-story/:storyId`, `/premium`).
///  - El resto de las pantallas de detalle (era, quiz, coleccionables,
///    galería, subtemas, créditos, ajustes...) NO se migraron: siguen
///    navegando exactamente igual que antes con `Navigator.push` /
///    `AppNavigation`, sin cambios. `Navigator.push` sigue funcionando con
///    normalidad bajo `MaterialApp.router` (empuja sobre el Navigator más
///    cercano — el de la pestaña activa, o el raíz si se llama desde fuera
///    del árbol, p. ej. el home widget nativo vía `AppNavigation.navigatorKey`,
///    que es el mismo `navigatorKey` que usa este router).
///  - Las 4 rutas nuevas son puntos de entrada ADICIONALES (deep link / URL),
///    no un reemplazo de `AppNavigation.openHistoriaArticle`/`openContent`:
///    esas siguen recibiendo el objeto ya cargado en memoria (instantáneo).
///    Las rutas de `go_router`, en cambio, solo reciben ids de la URL y
///    deben resolver el contenido de forma asíncrona (hay una carga breve
///    la primera vez que se entra por esta vía).
class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: AppNavigation.navigatorKey,
    initialLocation: '/splash',
    redirect: _redirect,
    routes: [
      // Respaldo para la pantalla de error por defecto de go_router (su link
      // "Home" apunta a '/'), y por si algo navega ahí directamente.
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      // Primer arranque. Fuera del shell a propósito: sin barra inferior,
      // para que nadie se salte la presentación tocando otra pestaña.
      GoRoute(
        path: OnboardingScreen.routePath,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        // `pageBuilder` (no `builder`) para poder envolver el shell completo
        // (MainScreen + bottom nav) en el mismo fade de 700ms que tenía el
        // `Navigator.pushReplacement` original de SplashScreen → MainScreen.
        pageBuilder: (context, state, navigationShell) => CustomTransitionPage(
          key: state.pageKey,
          child: MainScreen(navigationShell: navigationShell),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 700),
        ),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/map', builder: (_, __) => const MapTimelineScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/favorites', builder: (_, __) => const FavoritesScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/historia/:stageId/:articleId',
        builder: (context, state) => _HistoriaArticleRoute(
          stageId: state.pathParameters['stageId']!,
          articleId: state.pathParameters['articleId']!,
        ),
      ),
      GoRoute(
        path: '/content/:id',
        builder: (context, state) => _ContentRoute(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/interactive-story/:storyId',
        builder: (context, state) => InteractiveStoryScreen(
          storyId: state.pathParameters['storyId']!,
        ),
      ),
      GoRoute(path: '/premium', builder: (context, state) => const PremiumScreen()),
    ],
  );

  /// Guarda de gating centralizada para las rutas deep-linkeables — replica
  /// (no reemplaza) las mismas reglas que `AppNavigation.openHistoriaArticle`
  /// / `openContent` aplican hoy antes de un `Navigator.push`. Necesita
  /// cargar el contenido apuntado por la URL para poder decidir, así que es
  /// asíncrona; mientras resuelve, `go_router` mantiene la ruta anterior.
  static Future<String?> _redirect(BuildContext context, GoRouterState state) async {
    // Deep links con scheme propio (perueterno://home, perueterno://historia/
    // peru_prehispanico/caral): en esa URI el host es el primer segmento del
    // path interno de la app ('home', 'historia'), no una ruta reconocible
    // tal cual — go_router intentaría matchear la URI completa y fallaría
    // ("no routes for location: perueterno://..."). La reescribimos aquí a
    // la ruta interna equivalente; go_router vuelve a invocar este redirect
    // sobre la ubicación ya normalizada (sin scheme, así que esta rama no se
    // repite) y el gating de abajo se aplica con normalidad en esa segunda
    // pasada.
    final uri = state.uri;
    if (uri.scheme == 'perueterno') {
      if (uri.host.isEmpty) return '/home';
      return '/${uri.host}${uri.path}';
    }

    final path = state.matchedLocation;
    final isPremiumUser = context.read<PremiumProvider>().isPremium;
    if (isPremiumUser) return null; // Premium: nunca bloqueado.

    if (path.startsWith('/historia/')) {
      final articleId = state.pathParameters['articleId'];
      if (articleId == null) return null;
      final dailyId = context.read<DailyStoryProvider>().dailyArticle?.id;
      return articleId == dailyId ? null : '/premium';
    }

    if (path.startsWith('/content/')) {
      final id = state.pathParameters['id'];
      if (id == null) return null;
      final item = ContentRepository.findById(id);
      if (item == null) return null; // Id inexistente: que la pantalla lo maneje.
      if (CategoryConfigs.isComingSoon(item.category)) return '/explore';
      return item.isPremium ? '/premium' : null;
    }

    if (path.startsWith('/interactive-story/')) {
      final storyId = state.pathParameters['storyId'];
      if (storyId == null) return null;
      final story = await InteractiveStoryRepository.loadStory(storyId);
      return (story?.isPremium ?? false) ? '/premium' : null;
    }

    return null;
  }
}

/// Resuelve `/historia/:stageId/:articleId` a partir de los ids de la URL:
/// carga la etapa y sus artículos (para prev/next, igual que
/// `AppNavigation.openHistoriaArticle`) y entrega el mismo
/// [HistoriaArticleDetailScreen] que usa la navegación interna.
class _HistoriaArticleRoute extends StatelessWidget {
  final String stageId;
  final String articleId;

  const _HistoriaArticleRoute({required this.stageId, required this.articleId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(HistoriaStage?, List<HistoriaArticle>)>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: AppLoadingState());
        }
        final (stage, articles) = snap.data ?? (null, const <HistoriaArticle>[]);
        final article = articles.cast<HistoriaArticle?>().firstWhere(
              (a) => a?.id == articleId,
              orElse: () => null,
            );
        if (article == null) {
          return const Scaffold(body: AppErrorState());
        }
        return HistoriaArticleDetailScreen(
          article: article,
          allArticles: articles,
          stage: stage,
          carouselImages: HistoriaStagesRepository.carouselImagesForStage(stageId),
        );
      },
    );
  }

  Future<(HistoriaStage?, List<HistoriaArticle>)> _load() async {
    final stages = await HistoriaStagesRepository.loadStages();
    final stage = stages.cast<HistoriaStage?>().firstWhere(
          (s) => s?.id == stageId,
          orElse: () => null,
        );
    final articles = await HistoriaStagesRepository.loadArticlesForStage(stageId);
    return (stage, articles);
  }
}

/// Resuelve `/content/:id` — mismo `ContentItem` (genérico o derivado de una
/// era, ver `ContentRepository`) que usa `AppNavigation.openContent`.
class _ContentRoute extends StatelessWidget {
  final String id;
  const _ContentRoute({required this.id});

  @override
  Widget build(BuildContext context) {
    final item = ContentRepository.findById(id);
    if (item == null) return const Scaffold(body: AppErrorState());
    return ContentDetailScreen(item: item);
  }
}
