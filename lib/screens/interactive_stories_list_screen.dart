import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigation.dart';
import '../data/interactive_story_repository.dart';
import '../models/interactive_story.dart';
import '../providers/language_provider.dart';
import '../providers/interactive_story_provider.dart';
import '../providers/premium_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/app_state_views.dart';
import '../widgets/cinematic_card.dart';
import 'interactive_story_screen.dart';

/// Hub de historias interactivas ("Elige tu camino"): lista las historias
/// disponibles (hoy solo "La Misión del Chasqui") como tarjetas cinemáticas;
/// las historias premium quedan bloqueadas para usuarios free.
class InteractiveStoriesListScreen extends StatefulWidget {
  const InteractiveStoriesListScreen({super.key});

  @override
  State<InteractiveStoriesListScreen> createState() =>
      _InteractiveStoriesListScreenState();
}

class _InteractiveStoriesListScreenState
    extends State<InteractiveStoriesListScreen> {
  late Future<List<InteractiveStory>> _stories;

  @override
  void initState() {
    super.initState();
    _stories = InteractiveStoryRepository.loadAllStories();
    // El contador de finales sale de SharedPreferences, no del árbol de la
    // historia cargada, así que hay que pedirlo explícitamente. Se repite al
    // volver de una historia (ver [_openStory]) para que el final que acabas
    // de descubrir se vea al instante.
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    final stories = await _stories;
    if (!mounted) return;
    await context
        .read<InteractiveStoryProvider>()
        .loadUnlockedCounts(stories.map((s) => s.id));
  }

  Future<void> _openStory(InteractiveStory story) async {
    context
        .read<AnalyticsService>()
        .log(AnalyticsService.storyStart, target: story.id);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InteractiveStoryScreen(storyId: story.id),
      ),
    );
    await _refreshCounts();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final t = context.watch<LanguageProvider>().t;
    final isPremium = context.watch<PremiumProvider>().isPremium;
    // `watch`, no `read`: el sync puede traer finales de otro dispositivo con
    // esta pantalla abierta y el contador debe reflejarlo.
    final isp = context.watch<InteractiveStoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.cremaPergamino, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('interactive_stories.hub_title'),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cremaPergamino,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('interactive_stories.hub_subtitle'),
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: AppColors.cremaPergamino.withOpacity(0.6),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<InteractiveStory>>(
                future: _stories,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const AppLoadingState(
                        color: AppColors.ocre, height: 300);
                  }
                  final stories = snap.data ?? [];
                  if (stories.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.auto_stories_rounded,
                      title: t('interactive_stories.hub_empty'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    itemCount: stories.length,
                    itemBuilder: (context, i) {
                      final story = stories[i];
                      final isLocked = story.isPremium && !isPremium;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: CinematicCard(
                          assetImagePath: story.coverImage.isNotEmpty
                              ? story.coverImage
                              : null,
                          accentColor: AppColors.ocre,
                          title: story.tituloFor(lang),
                          subtitle: story.descripcionFor(lang),
                          // El candado premium manda sobre el contador: a
                          // quien no puede entrar no se le enseña su progreso.
                          badge: isLocked
                              ? t('interactive_stories.premium_story_badge')
                              : _endingsBadge(t, story, isp),
                          isPremium: isLocked,
                          height: 210,
                          onTap: () {
                            if (isLocked) {
                              AppNavigation.openPremium(
                                context,
                                source: 'story_lock',
                              );
                              return;
                            }
                            _openStory(story);
                          },
                        )
                            .animate()
                            .fadeIn(
                                duration: 400.ms,
                                delay: Duration(milliseconds: i * 80))
                            .slideY(
                                begin: 0.06,
                                end: 0,
                                duration: 400.ms,
                                delay: Duration(milliseconds: i * 80)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "2 de 4 finales" en la tarjeta. Estos finales se guardaban y se
  /// sincronizaban pero no se enseñaban en ninguna pantalla, así que el
  /// usuario no tenía forma de saber que había ramas sin descubrir — ni
  /// motivo para rejugar. Sin ninguno descubierto no se pone nada: un "0 de 4"
  /// en la primera visita es ruido, no un incentivo.
  String? _endingsBadge(
    String Function(String) t,
    InteractiveStory story,
    InteractiveStoryProvider isp,
  ) {
    final total = story.endingCount;
    if (total == 0) return null;
    final unlocked = isp.unlockedEndingsFor(story.id);
    if (unlocked == 0) return null;
    if (unlocked >= total) return t('interactive_stories.endings_all');
    return t('interactive_stories.endings_progress')
        .replaceAll('{unlocked}', '$unlocked')
        .replaceAll('{total}', '$total');
  }
}
