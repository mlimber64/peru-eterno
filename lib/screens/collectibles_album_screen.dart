import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigation.dart';
import '../data/historia_stages_repository.dart';
import '../models/collectible_card.dart';
import '../models/historia_article.dart';
import '../models/historia_stage.dart';
import '../providers/collectibles_provider.dart';
import '../providers/language_provider.dart';
import '../services/share_service.dart';

/// Álbum de tarjetas coleccionables, agrupado por etapa histórica. Las
/// tarjetas bloqueadas se muestran en escala de grises con una pista de
/// desbloqueo; las desbloqueadas brillan según su rareza.
class CollectiblesAlbumScreen extends StatelessWidget {
  const CollectiblesAlbumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final t = context.read<LanguageProvider>();
    final collectibles = context.watch<CollectiblesProvider>();
    final stages = collectibles.stagesInOrder;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      appBar: AppBar(
        title: Text(
          t.t('collectibles.title'),
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: AppColors.cremaPergamino,
          ),
        ),
      ),
      body: stages.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.ocre))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                _ProgressHeader(
                  unlocked: collectibles.unlockedCount,
                  total: collectibles.totalCount,
                ),
                const SizedBox(height: 16),
                for (final stage in stages) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 12),
                    child: Row(
                      children: [
                        Container(width: 3, height: 16, color: stage.accentColor),
                        const SizedBox(width: 10),
                        Text(
                          stage.tituloFor(lang).toUpperCase(),
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.cremaPergamino,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                    children: collectibles.cards
                        .where((c) => c.stageId == stage.id)
                        .map((c) => _CollectibleTile(card: c, lang: lang))
                        .toList(),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int unlocked;
  final int total;
  const _ProgressHeader({required this.unlocked, required this.total});

  @override
  Widget build(BuildContext context) {
    final t = context.read<LanguageProvider>();
    final pct = total == 0 ? 0.0 : unlocked / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.marronProfundo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ocre.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.ocre, size: 18),
              const SizedBox(width: 8),
              Text(
                '$unlocked / $total',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cremaPergamino,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                t.t('collectibles.progress_label'),
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: AppColors.cremaPergamino.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.ocre.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation(AppColors.ocre),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectibleTile extends StatelessWidget {
  final CollectibleCard card;
  final String lang;
  const _CollectibleTile({required this.card, required this.lang});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => card.isUnlocked
          ? _showUnlockedDetail(context)
          : _showLockedHint(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: card.isUnlocked
                ? card.rarity.color
                : AppColors.cremaPergamino.withOpacity(0.15),
            width: card.isUnlocked ? 2 : 1,
          ),
          boxShadow: card.isUnlocked
              ? [
                  BoxShadow(
                    color: card.rarity.color.withOpacity(0.45),
                    blurRadius: 12,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _cardImage(),
            if (!card.isUnlocked)
              Container(
                color: Colors.black.withOpacity(0.55),
                child: const Center(
                  child: Icon(Icons.lock_rounded, color: Colors.white70, size: 22),
                ),
              ),
            if (card.isUnlocked)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Text(
                  card.tituloFor(lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cardImage() {
    final img = Image.asset(
      card.imagen,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: AppColors.marronProfundo),
    );
    if (card.isUnlocked) return img;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: img,
    );
  }

  void _showLockedHint(BuildContext context) {
    final t = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.marronProfundo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.lock_rounded, color: AppColors.ocre, size: 32),
        content: Text(
          '${t.t('collectibles.locked_prefix')} ${card.tituloFor(lang)} '
          '${t.t('collectibles.locked_suffix')}',
          textAlign: TextAlign.center,
          style: GoogleFonts.lato(color: AppColors.cremaPergamino, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.t('quiz.close')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.ocre),
            onPressed: () async {
              Navigator.pop(ctx);
              await _openChapter(context);
            },
            child: Text(t.t('collectibles.go_to_chapter')),
          ),
        ],
      ),
    );
  }

  Future<void> _openChapter(BuildContext context) async {
    final stages = await HistoriaStagesRepository.loadStages();
    final stage = stages.cast<HistoriaStage?>().firstWhere(
          (s) => s?.id == card.stageId,
          orElse: () => null,
        );
    if (stage == null || !context.mounted) return;
    final articles = await HistoriaStagesRepository.loadArticlesForStage(stage.id);
    final article = articles.cast<HistoriaArticle?>().firstWhere(
          (a) => a?.id == card.id,
          orElse: () => null,
        );
    if (article == null || !context.mounted) return;
    AppNavigation.openHistoriaArticle(
      context,
      article: article,
      allArticles: articles,
      stage: stage,
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _showUnlockedDetail(BuildContext context) {
    final t = context.read<LanguageProvider>();
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: card.rarity.color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: card.rarity.color.withOpacity(0.55),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
                color: AppColors.marronProfundo,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 0.9,
                    child: Image.asset(
                      card.imagen,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: AppColors.marronProfundo),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: card.rarity.color.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: card.rarity.color),
                          ),
                          child: Text(
                            t.t(card.rarity.labelKey()).toUpperCase(),
                            style: GoogleFonts.lato(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: card.rarity.color,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          card.tituloFor(lang),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cremaPergamino,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          card.descripcionFor(lang),
                          style: GoogleFonts.lato(
                            fontSize: 12.5,
                            color: AppColors.cremaPergamino.withOpacity(0.75),
                            height: 1.5,
                          ),
                        ),
                        if (card.unlockedAt != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            '${t.t('collectibles.unlocked_on')} '
                            '${_formatDate(card.unlockedAt!)}',
                            style: GoogleFonts.lato(
                              fontSize: 10.5,
                              color: AppColors.cremaPergamino.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Compartir justo aquí y no en la cuadrícula: este es el momento
            // en que alguien acaba de ver la carta que desbloqueó, que es
            // cuando de verdad le apetece enseñarla.
            FilledButton.icon(
              onPressed: () => ShareService.share(
                message: t
                    .t('share.collectible')
                    .replaceAll('{card}', card.tituloFor(lang)),
                subject: t.t('share.collectible_subject'),
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: Text(
                t.t('share.button'),
                style: GoogleFonts.lato(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: card.rarity.color,
                foregroundColor: AppColors.negoCacao,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.t('quiz.close'),
                  style: const TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
