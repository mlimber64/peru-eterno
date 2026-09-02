import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigation.dart';
import '../data/interactive_story_repository.dart';
import '../models/interactive_story.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/app_state_views.dart';
import '../widgets/cinematic_card.dart';
import 'interactive_story_screen.dart';

/// Hub de historias interactivas ("Elige tu camino"): lista las historias
/// disponibles (hoy solo "La Misión del Chasqui") como tarjetas cinemáticas;
/// las historias premium quedan bloqueadas para usuarios free.
class InteractiveStoriesListScreen extends StatelessWidget {
  const InteractiveStoriesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final t = context.watch<LanguageProvider>().t;
    final isPremium = context.watch<PremiumProvider>().isPremium;

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
                future: InteractiveStoryRepository.loadAllStories(),
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
                          badge: isLocked
                              ? t('interactive_stories.premium_story_badge')
                              : null,
                          isPremium: isLocked,
                          height: 210,
                          onTap: () {
                            if (isLocked) {
                              AppNavigation.openPremium(context);
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InteractiveStoryScreen(storyId: story.id),
                              ),
                            );
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
}
