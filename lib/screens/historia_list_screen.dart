import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigation.dart';
import '../data/historia_repository.dart';
import '../models/historia_article.dart';
import '../providers/daily_story_provider.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/app_state_views.dart';
import '../widgets/historia_rich_text.dart';

class HistoriaListScreen extends StatelessWidget {
  const HistoriaListScreen({super.key});

  static const _accent = AppColors.worldHistoria;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, lang),
          SliverToBoxAdapter(
            child: FutureBuilder<List<HistoriaArticle>>(
              future: HistoriaRepository.loadAll(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const AppLoadingState(
                    height: 300,
                    color: _accent,
                  );
                }
                if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
                  return const AppErrorState(height: 300);
                }
                final articles = snap.data!;
                return _ArticleListBody(articles: articles, lang: lang);
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, String lang) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF3E0800),
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFC1440E), Color(0xFF3E0800)],
                ),
              ),
            ),
            CustomPaint(painter: _DiagPainter(_accent)),
            Positioned(
              right: -20,
              top: 10,
              child: Icon(
                Icons.history_edu_rounded,
                size: 200,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.negoCacao],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history_edu_rounded, size: 14, color: _accent),
                      const SizedBox(width: 8),
                      Text(
                        context
                            .read<LanguageProvider>()
                            .t('historia.editorial_articles'),
                        style: GoogleFonts.lato(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context
                        .read<LanguageProvider>()
                        .t('historia.prehispanic_peru'),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context
                        .read<LanguageProvider>()
                        .t('historia.prehispanic_subtitle'),
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleListBody extends StatelessWidget {
  final List<HistoriaArticle> articles;
  final String lang;

  const _ArticleListBody({required this.articles, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          for (int i = 0; i < articles.length; i++)
            _ArticleCard(
              article: articles[i],
              allArticles: articles,
              lang: lang,
              index: i,
            ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final HistoriaArticle article;
  final List<HistoriaArticle> allArticles;
  final String lang;
  final int index;

  static const _accent = AppColors.worldHistoria;

  const _ArticleCard({
    required this.article,
    required this.allArticles,
    required this.lang,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final preview = _previewText();
    final isPremium = context.watch<PremiumProvider>().isPremium;
    final isDaily =
        context.watch<DailyStoryProvider>().dailyArticle?.id == article.id;
    final isLocked = !isPremium && !isDaily;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.marronProfundo,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => AppNavigation.openHistoriaArticle(
            context,
            article: article,
            allArticles: allArticles,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withOpacity(0.12)),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Orden badge (o candado si el artículo está bloqueado)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: isLocked
                        ? Icon(Icons.lock_rounded, size: 15, color: _accent)
                        : Text(
                            '${article.orden}',
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _accent,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.categoriaFor(lang).toUpperCase(),
                        style: GoogleFonts.lato(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _accent.withOpacity(0.75),
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.tituloFor(lang),
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cremaPergamino,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        article.subtituloFor(lang),
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.cremaPergamino.withOpacity(0.55),
                          height: 1.3,
                        ),
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          preview,
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            color: AppColors.cremaPergamino.withOpacity(0.6),
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            context.read<LanguageProvider>().t(
                                  isLocked
                                      ? 'premium.locked_label'
                                      : 'historia.read_article',
                                ),
                            style: GoogleFonts.lato(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _accent,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isLocked
                                ? Icons.lock_rounded
                                : Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: _accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 450.ms, delay: (index * 80).ms)
        .slideY(begin: 0.06, end: 0, duration: 450.ms, delay: (index * 80).ms);
  }

  String _previewText() {
    final content = article.contenidoFor(lang);
    final paragraphs =
        content.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    if (paragraphs.isEmpty) return '';
    final first = HistoriaParagraph.stripMarkdown(paragraphs.first.trim());
    return first.length > 120 ? '${first.substring(0, 120)}…' : first;
  }
}

class _DiagPainter extends CustomPainter {
  final Color color;
  const _DiagPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.07)
      ..strokeWidth = 1;
    const spacing = 28.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
