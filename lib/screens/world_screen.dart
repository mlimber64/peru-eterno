import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/category_config.dart';
import '../core/constants/world_config.dart';
import '../data/content_repository.dart';
import '../data/eras_repository.dart';
import '../models/content_item.dart';
import '../models/era_model.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/cinematic_card.dart';
import '../widgets/wiki_cinematic_card.dart';
import 'content_detail_screen.dart';
import 'era_detail_screen.dart';
import 'premium_screen.dart';

class WorldScreen extends StatelessWidget {
  final String worldId;
  const WorldScreen({super.key, required this.worldId});

  @override
  Widget build(BuildContext context) {
    final world = WorldConfig.findById(worldId);
    if (world == null) return const SizedBox.shrink();

    final lang = context.watch<LanguageProvider>().currentLanguage;
    final isPremium = context.watch<PremiumProvider>().isPremium;

    final items = _itemsForWorld(world);
    final eras = world.category == 'era' ? ErasRepository.allEras : <EraModel>[];

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: CustomScrollView(
        slivers: [
          // ── Cinematic hero ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: world.accentColorDark,
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
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          world.accentColor.withOpacity(0.85),
                          world.accentColorDark,
                        ],
                      ),
                    ),
                  ),
                  // Pattern
                  CustomPaint(
                    painter: _DiagPainter(world.accentColor),
                  ),
                  // Large icon bg
                  Positioned(
                    right: -20,
                    top: 20,
                    child: Icon(
                      world.icon,
                      size: 200,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  // Bottom gradient
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
                  // Content
                  Positioned(
                    bottom: 28,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(world.icon,
                                size: 16, color: world.accentColor),
                            const SizedBox(width: 8),
                            Text(
                              world.titleFor(lang).toUpperCase(),
                              style: GoogleFonts.lato(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: world.accentColor,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          world.titleFor(lang),
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          world.descriptionFor(lang),
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Timeline for Historia ────────────────────────────────────────
          if (eras.isNotEmpty) ...[
            _sliverLabel(_timelineLabel(lang), world.accentColor),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: eras.length,
                  itemBuilder: (context, i) {
                    final era = eras[i];
                    final isLocked = era.isPremium && !isPremium;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: CinematicCard(
                        assetImagePath:
                            era.imageAssetPath(era.imageFilenames.first),
                        accentColor: era.accentColor,
                        title: context
                            .read<LanguageProvider>()
                            .t('eras.${era.id}.period'),
                        subtitle: context
                            .read<LanguageProvider>()
                            .t('eras.${era.id}.title'),
                        isPremium: isLocked,
                        width: 140,
                        height: 160,
                        onTap: isLocked
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const PremiumScreen()))
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => EraDetailScreen(era: era))),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: (i * 70).ms),
                    );
                  },
                ),
              ),
            ),
            _sliverLabel(_civilizationsLabel(lang), world.accentColor),
          ],

          // ── Content grid ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final item = items[i];
                  final era = item.category == 'era'
                      ? ErasRepository.allEras
                          .cast<EraModel?>()
                          .firstWhere((e) => e?.id == item.id,
                              orElse: () => null)
                      : null;
                  final isLocked = item.isPremium && !isPremium;
                  final tapAction = isLocked
                      ? () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PremiumScreen()))
                      : era != null
                          ? () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => EraDetailScreen(era: era)))
                          : () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ContentDetailScreen(item: item)));

                  if (era != null) {
                    return CinematicCard(
                      assetImagePath: era.imageAssetPath(era.imageFilenames.first),
                      accentColor: era.accentColor,
                      title: context.read<LanguageProvider>().t('eras.${era.id}.title'),
                      subtitle: context.read<LanguageProvider>().t('eras.${era.id}.period'),
                      isPremium: isLocked,
                      onTap: tapAction,
                    )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (i * 60).ms)
                        .scale(begin: const Offset(0.93, 0.93), duration: 400.ms, delay: (i * 60).ms);
                  }

                  return WikiCinematicCard(
                    item: item,
                    subtitle: CategoryConfigs.labelOf(item.category, lang),
                    isPremium: isLocked,
                    onTap: tapAction,
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: (i * 60).ms)
                      .scale(
                        begin: const Offset(0.93, 0.93),
                        end: const Offset(1, 1),
                        duration: 400.ms,
                        delay: (i * 60).ms,
                      );
                },
                childCount: items.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliverLabel(String label, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
        child: Row(
          children: [
            Container(width: 3, height: 16, color: color),
            const SizedBox(width: 10),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.lato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.cremaPergamino,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ContentItem> _itemsForWorld(WorldEntry world) {
    return switch (world.category) {
      'era' => ContentRepository.eras,
      'tradicion' => ContentRepository.tradiciones,
      'gastronomia' => ContentRepository.gastronomia,
      'musica' => ContentRepository.musica,
      'geografia' => ContentRepository.geografia,
      _ => [],
    };
  }

  String _timelineLabel(String lang) => switch (lang) {
        'en' => 'Timeline',
        'it' => 'Cronologia',
        _ => 'Línea de tiempo',
      };
  String _civilizationsLabel(String lang) => switch (lang) {
        'en' => 'Civilizations',
        'it' => 'Civiltà',
        _ => 'Civilizaciones',
      };
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
