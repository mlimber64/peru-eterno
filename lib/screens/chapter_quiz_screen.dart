import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/analytics_service.dart';
import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigation.dart';
import '../models/collectible_card.dart';
import '../models/historia_article.dart';
import '../models/quiz_question.dart';
import '../providers/collectibles_provider.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../services/review_prompt_service.dart';
import 'collectibles_album_screen.dart';

/// Flujo de evaluación de un capítulo: 3 preguntas de opción múltiple con
/// feedback inmediato, seguidas de una pantalla de resultados con la
/// recompensa de tarjeta coleccionable.
class ChapterQuizScreen extends StatefulWidget {
  final HistoriaArticle article;
  final String lang;

  const ChapterQuizScreen({
    super.key,
    required this.article,
    required this.lang,
  });

  @override
  State<ChapterQuizScreen> createState() => _ChapterQuizScreenState();
}

class _ChapterQuizScreenState extends State<ChapterQuizScreen> {
  static const _correctColor = Color(0xFF2ECC71);
  static const _incorrectColor = Color(0xFFE85B4E);

  int _index = 0;
  int? _selected;
  int _score = 0;
  bool _showResults = false;

  List<QuizQuestion> get _quiz => widget.article.quiz;

  void _selectOption(int i) {
    if (_selected != null) return;
    setState(() {
      _selected = i;
      if (i == _quiz[_index].respuestaCorrecta) _score++;
    });
  }

  void _next() {
    if (_index < _quiz.length - 1) {
      setState(() {
        _index++;
        _selected = null;
      });
    } else {
      setState(() => _showResults = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.read<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      appBar: AppBar(
        title: Text(
          t.t('quiz.title'),
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: AppColors.cremaPergamino,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _showResults ? _buildResults(context, t) : _buildQuestion(t),
      ),
    );
  }

  // ── Pregunta ─────────────────────────────────────────────────────────────

  Widget _buildQuestion(LanguageProvider t) {
    final q = _quiz[_index];
    final options = q.opcionesFor(widget.lang);
    final answered = _selected != null;
    final isCorrectSelected = _selected == q.respuestaCorrecta;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              _quiz.length,
              (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < _quiz.length - 1 ? 6 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= _index
                        ? AppColors.ocre
                        : AppColors.ocre.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_index + 1}/${_quiz.length}',
            style: GoogleFonts.lato(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.ocre,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            q.preguntaFor(widget.lang),
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.cremaPergamino,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _OptionTile(
                text: options[i],
                state: !answered
                    ? _OptionState.idle
                    : i == q.respuestaCorrecta
                        ? _OptionState.correct
                        : i == _selected
                            ? _OptionState.incorrect
                            : _OptionState.disabled,
                onTap: () => _selectOption(i),
              ),
            ),
          ),
          if (answered) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isCorrectSelected ? _correctColor : _incorrectColor)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isCorrectSelected ? _correctColor : _incorrectColor)
                      .withOpacity(0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCorrectSelected
                        ? Icons.check_circle_rounded
                        : Icons.info_rounded,
                    size: 18,
                    color: isCorrectSelected ? _correctColor : _incorrectColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      q.explicacionFor(widget.lang),
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: AppColors.cremaPergamino.withOpacity(0.85),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ocre,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  _index < _quiz.length - 1
                      ? t.t('quiz.next')
                      : t.t('quiz.see_results'),
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.negoCacao,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Resultados ───────────────────────────────────────────────────────────

  Widget _buildResults(BuildContext context, LanguageProvider t) {
    final total = _quiz.length;
    final scoreLabel = _score == total
        ? t.t('quiz.score_perfect')
        : _score >= (total / 2).ceil()
            ? t.t('quiz.score_good')
            : t.t('quiz.score_low');
    final collectibles = context.watch<CollectiblesProvider>();
    final alreadyUnlocked = collectibles.isUnlocked(widget.article.id);
    final card = collectibles.cards
        .cast<CollectibleCard?>()
        .firstWhere((c) => c?.id == widget.article.id, orElse: () => null);
    final isPremium = context.watch<PremiumProvider>().isPremium;
    final isLockedRarity = card != null &&
        !isPremium &&
        (card.rarity == CardRarity.epica || card.rarity == CardRarity.legendaria);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.ocre.withOpacity(0.12),
              border: Border.all(color: AppColors.ocre.withOpacity(0.4), width: 3),
            ),
            child: Center(
              child: Text(
                '$_score/$total',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ocre,
                ),
              ),
            ),
          ).animate().scale(duration: 450.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            scoreLabel,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.cremaPergamino,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: alreadyUnlocked
                  ? null
                  : isLockedRarity
                      ? () => AppNavigation.openPremium(context)
                      : () => _claimCard(context, t),
              icon: Icon(alreadyUnlocked
                  ? Icons.check_circle_rounded
                  : isLockedRarity
                      ? Icons.lock_rounded
                      : Icons.card_giftcard_rounded),
              label: Text(
                alreadyUnlocked
                    ? t.t('quiz.already_claimed')
                    : isLockedRarity
                        ? t.t('quiz.claim_card_locked')
                        : t.t('quiz.claim_card'),
                style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ocre,
                foregroundColor: AppColors.negoCacao,
                disabledBackgroundColor: AppColors.ocre.withOpacity(0.25),
                disabledForegroundColor: AppColors.cremaPergamino.withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _claimCard(BuildContext context, LanguageProvider t) async {
    final collectibles = context.read<CollectiblesProvider>();
    final review = context.read<ReviewPromptService>();
    await collectibles.recordQuizScore(widget.article.id, _score);
    final esNueva = await collectibles.unlockCard(widget.article.id);

    // `value` = aciertos (0-3). Un capítulo cuyo quiz saca siempre 0 es un
    // capítulo mal escrito o unas preguntas mal formuladas, y eso solo se ve
    // aquí.
    final analytics = context.read<AnalyticsService>();
    analytics.log(AnalyticsService.quizComplete,
        target: widget.article.id, value: _score);
    if (esNueva) {
      analytics.log(AnalyticsService.cardUnlock, target: widget.article.id);
    }

    // Acaba de superar un quiz y ganar una carta: es el mejor momento para
    // pedirle una valoración. El servicio decide si toca o no — no la pide
    // hasta el tercer momento bueno.
    unawaited(review.registerGoodMoment());

    if (!context.mounted) return;

    final card = collectibles.cards.firstWhere((c) => c.id == widget.article.id);

    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 220,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: card.rarity.color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: card.rarity.color.withOpacity(0.6),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    card.imagen,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppColors.marronProfundo),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Text(
                      card.tituloFor(widget.lang),
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().scale(duration: 550.ms, curve: Curves.elasticOut).fadeIn(),
            const SizedBox(height: 20),
            Text(
              t.t('quiz.card_claimed'),
              style: GoogleFonts.lato(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(t.t('quiz.close'),
                      style: const TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CollectiblesAlbumScreen(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(backgroundColor: card.rarity.color),
                  child: Text(t.t('quiz.view_album')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _OptionState { idle, correct, incorrect, disabled }

class _OptionTile extends StatelessWidget {
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  const _OptionTile({
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Color bg;
    switch (state) {
      case _OptionState.idle:
        color = AppColors.cremaPergamino.withOpacity(0.7);
        bg = AppColors.marronProfundo;
      case _OptionState.correct:
        color = const Color(0xFF2ECC71);
        bg = const Color(0xFF2ECC71).withOpacity(0.14);
      case _OptionState.incorrect:
        color = const Color(0xFFE85B4E);
        bg = const Color(0xFFE85B4E).withOpacity(0.14);
      case _OptionState.disabled:
        color = AppColors.cremaPergamino.withOpacity(0.3);
        bg = AppColors.marronProfundo.withOpacity(0.5);
    }

    Widget tile = Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: state == _OptionState.idle ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              if (state == _OptionState.correct)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2ECC71), size: 18),
              if (state == _OptionState.incorrect)
                const Icon(Icons.cancel_rounded,
                    color: Color(0xFFE85B4E), size: 18),
            ],
          ),
        ),
      ),
    );

    if (state == _OptionState.incorrect) {
      tile = tile.animate().shake(duration: 400.ms, hz: 4);
    }
    return tile;
  }
}
