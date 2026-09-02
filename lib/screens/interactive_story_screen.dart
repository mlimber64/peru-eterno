import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/analytics_service.dart';
import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigation.dart';
import '../models/interactive_story.dart';
import '../providers/interactive_story_provider.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../services/review_prompt_service.dart';
import '../services/share_service.dart';
import '../widgets/app_state_views.dart';

/// Lector de historias interactivas ("Elige tu camino"): muestra el nodo
/// actual de [InteractiveStoryProvider] con transiciones animadas, revela el
/// "Dato Real" tras cada decisión y termina en una pantalla de resumen al
/// llegar a un final.
class InteractiveStoryScreen extends StatefulWidget {
  final String storyId;

  const InteractiveStoryScreen({super.key, required this.storyId});

  @override
  State<InteractiveStoryScreen> createState() =>
      _InteractiveStoryScreenState();
}

class _InteractiveStoryScreenState extends State<InteractiveStoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InteractiveStoryProvider>().loadStory(widget.storyId);
    });
  }

  void _onSelectChoice(StoryChoice choice) {
    final isPremium = context.read<PremiumProvider>().isPremium;
    if (choice.requiredPremium && !isPremium) {
      AppNavigation.openPremium(context);
      return;
    }
    context.read<InteractiveStoryProvider>().selectChoice(choice);
  }

  @override
  Widget build(BuildContext context) {
    final isp = context.watch<InteractiveStoryProvider>();
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final t = context.watch<LanguageProvider>().t;
    final story = isp.story;
    final node = isp.currentNode;

    if (story == null || node == null || story.id != widget.storyId) {
      return const Scaffold(
        backgroundColor: AppColors.negoCacao,
        body: AppLoadingState(color: AppColors.ocre, height: 400),
      );
    }

    final progress = node.isEnding
        ? 1.0
        : ((isp.path.length - 1) / story.shortestPathToEnding).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: SafeArea(
        child: Column(
          children: [
            _StoryHeader(node: node, progress: progress),
            Expanded(
              child: node.isEnding
                  ? _EndingView(story: story, node: node, lang: lang, t: t)
                  : _PlayBody(
                      node: node,
                      lang: lang,
                      t: t,
                      isShowingFact: isp.isShowingFact,
                      onSelectChoice: _onSelectChoice,
                      onConfirmFact: () =>
                          context.read<InteractiveStoryProvider>().confirmFact(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header: imagen de escena con gradiente + barra de progreso ─────────────

class _StoryHeader extends StatelessWidget {
  final InteractiveStoryNode node;
  final double progress;

  const _StoryHeader({required this.node, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: KeyedSubtree(
              key: ValueKey(node.nodeId),
              child: node.imagePath != null
                  ? Image.asset(
                      node.imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _HeaderFallback(),
                    )
                  : const _HeaderFallback(),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.black.withOpacity(0.15),
                  AppColors.negoCacao,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.cremaPergamino),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: AppColors.cremaPergamino.withOpacity(0.15),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.ocre),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderFallback extends StatelessWidget {
  const _HeaderFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.marronOscuro, AppColors.negoCacao],
        ),
      ),
      child: Center(
        child: Icon(Icons.terrain_rounded,
            size: 64, color: AppColors.ocre.withOpacity(0.25)),
      ),
    );
  }
}

// ── Cuerpo: narrativa + elecciones / dato real ──────────────────────────────

class _PlayBody extends StatelessWidget {
  final InteractiveStoryNode node;
  final String lang;
  final String Function(String) t;
  final bool isShowingFact;
  final ValueChanged<StoryChoice> onSelectChoice;
  final VoidCallback onConfirmFact;

  const _PlayBody({
    required this.node,
    required this.lang,
    required this.t,
    required this.isShowingFact,
    required this.onSelectChoice,
    required this.onConfirmFact,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<PremiumProvider>().isPremium;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: SingleChildScrollView(
        key: ValueKey('${node.nodeId}_$isShowingFact'),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              node.titleFor(lang),
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.cremaPergamino,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              node.narrativeFor(lang),
              style: GoogleFonts.lato(
                fontSize: 15,
                color: AppColors.cremaPergamino.withOpacity(0.85),
                height: 1.7,
              ),
            ),
            const SizedBox(height: 26),
            if (isShowingFact) ...[
              _HistoricalFactCard(
                text: node.historicalFactFor(lang) ?? '',
                label: t('interactive_stories.historical_fact_label'),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onConfirmFact,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ocre,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    t('interactive_stories.continue_button'),
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.negoCacao,
                    ),
                  ),
                ),
              ),
            ] else
              ...List.generate(node.choices.length, (i) {
                final choice = node.choices[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ChoiceCard(
                    choice: choice,
                    lang: lang,
                    isLocked: choice.requiredPremium && !isPremium,
                    premiumBadge: t('interactive_stories.premium_choice_badge'),
                    onTap: () => onSelectChoice(choice),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: (i * 90).ms)
                      .slideY(begin: 0.08, end: 0, duration: 400.ms, delay: (i * 90).ms),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _HistoricalFactCard extends StatelessWidget {
  final String text;
  final String label;

  const _HistoricalFactCard({required this.text, required this.label});

  @override
  Widget build(BuildContext context) {
    const gold = AppColors.ocre;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: gold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withOpacity(0.45), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: gold.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.menu_book_rounded, size: 14, color: gold),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.lato(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: gold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: GoogleFonts.lato(
              fontSize: 14,
              color: AppColors.cremaPergamino.withOpacity(0.9),
              height: 1.65,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0);
  }
}

class _ChoiceCard extends StatelessWidget {
  final StoryChoice choice;
  final String lang;
  final bool isLocked;
  final String premiumBadge;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.choice,
    required this.lang,
    required this.isLocked,
    required this.premiumBadge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isLocked ? AppColors.ocre.withOpacity(0.5) : AppColors.ocre.withOpacity(0.3);

    return Material(
      color: AppColors.marronProfundo,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        splashColor: AppColors.ocre.withOpacity(0.15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  choice.textFor(lang),
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cremaPergamino,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.ocre.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, size: 12, color: AppColors.ocre),
                      const SizedBox(width: 4),
                      Text(
                        premiumBadge,
                        style: GoogleFonts.lato(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ocre,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Icon(Icons.arrow_forward_rounded,
                    size: 18, color: AppColors.ocre.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Pantalla de finalización ────────────────────────────────────────────────

class _EndingView extends StatefulWidget {
  final InteractiveStory story;
  final InteractiveStoryNode node;
  final String lang;
  final String Function(String) t;

  const _EndingView({
    required this.story,
    required this.node,
    required this.lang,
    required this.t,
  });

  @override
  State<_EndingView> createState() => _EndingViewState();
}

class _EndingViewState extends State<_EndingView> {
  bool _showUnlockedBadge = false;

  @override
  void initState() {
    super.initState();
    final isp = context.read<InteractiveStoryProvider>();
    _showUnlockedBadge = isp.justUnlockedEnding;
    if (_showUnlockedBadge) {
      // Final nuevo desbloqueado: otro momento bueno para la valoración.
      unawaited(context.read<ReviewPromptService>().registerGoodMoment());
      context.read<AnalyticsService>().log(
            AnalyticsService.storyEnding,
            target: widget.story.id,
          );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<InteractiveStoryProvider>().consumeJustUnlockedEndingFlag();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = context.watch<InteractiveStoryProvider>().path;
    final pathTitles = path
        .map((id) => widget.story.node(id)?.titleFor(widget.lang))
        .whereType<String>()
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showUnlockedBadge)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.ocre.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.ocre.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.ocre),
                    const SizedBox(width: 6),
                    Text(
                      widget.t('interactive_stories.new_ending_unlocked'),
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ocre,
                      ),
                    ),
                  ],
                ),
              ).animate().scale(duration: 450.ms, curve: Curves.elasticOut),
            ),
          Text(
            widget.node.titleFor(widget.lang),
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.cremaPergamino,
              height: 1.25,
            ),
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 14),
          Text(
            widget.node.narrativeFor(widget.lang),
            style: GoogleFonts.lato(
              fontSize: 15,
              color: AppColors.cremaPergamino.withOpacity(0.85),
              height: 1.7,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms),
          if (widget.node.hasHistoricalFact) ...[
            const SizedBox(height: 22),
            _HistoricalFactCard(
              text: widget.node.historicalFactFor(widget.lang) ?? '',
              label: widget.t('interactive_stories.historical_fact_label'),
            ),
          ],
          if (pathTitles.isNotEmpty) ...[
            const SizedBox(height: 26),
            Text(
              widget.t('interactive_stories.your_path_title').toUpperCase(),
              style: GoogleFonts.lato(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.ocre,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            ...pathTitles.map(
              (title) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 6, color: AppColors.ocre.withOpacity(0.7)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.lato(
                          fontSize: 12.5,
                          color: AppColors.cremaPergamino.withOpacity(0.65),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.read<InteractiveStoryProvider>().restart(),
              icon: const Icon(Icons.replay_rounded),
              label: Text(
                widget.t('interactive_stories.restart_button'),
                style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ocre,
                foregroundColor: AppColors.negoCacao,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Compartir el final alcanzado: de todo lo que hace la app, es lo
          // que más invita a contarlo, porque el camino de cada uno es
          // distinto y da pie a comparar.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ShareService.share(
                message: widget
                    .t('share.story_ending')
                    .replaceAll('{story}', widget.story.tituloFor(widget.lang))
                    .replaceAll('{ending}', widget.node.titleFor(widget.lang)),
                subject: widget.t('share.story_subject'),
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ocre,
                side: BorderSide(color: AppColors.ocre.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              label: Text(
                widget.t('share.button'),
                style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.cremaPergamino,
                side: BorderSide(color: AppColors.cremaPergamino.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                widget.t('interactive_stories.back_to_hub_button'),
                style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
