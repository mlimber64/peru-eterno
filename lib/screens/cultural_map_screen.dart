import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigation.dart';
import '../data/content_repository.dart';
import '../data/historia_repository.dart';
import '../data/historia_stages_repository.dart';
import '../models/historia_article.dart';
import '../models/historia_stage.dart';
import '../providers/language_provider.dart';
import '../widgets/image_with_fallback.dart';

class CulturalMapScreen extends StatefulWidget {
  const CulturalMapScreen({super.key});

  @override
  State<CulturalMapScreen> createState() => _CulturalMapScreenState();
}

class _CulturalMapScreenState extends State<CulturalMapScreen> {
  int _selectedIndex = 0;

  CulturalMapPoint get _selected => culturalMapPoints[_selectedIndex];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 210,
            backgroundColor: AppColors.negoCacao,
            foregroundColor: AppColors.cremaPergamino,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _MapHero(lang: lang),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _MapStage(
                selectedIndex: _selectedIndex,
                onPointTap: (index) => setState(() => _selectedIndex = index),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _SelectedPointCard(
                point: _selected,
                lang: lang,
                onOpen: () => _openPoint(context, _selected, lang),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
              child: _SectionTitle(
                  label: context
                      .read<LanguageProvider>()
                      .t('cultural_map.places')),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
            sliver: SliverList.builder(
              itemCount: culturalMapPoints.length,
              itemBuilder: (context, index) {
                final point = culturalMapPoints[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MapPointListTile(
                    point: point,
                    lang: lang,
                    isSelected: index == _selectedIndex,
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      _openPoint(context, point, lang);
                    },
                  ),
                )
                    .animate()
                    .fadeIn(duration: 420.ms, delay: (index * 45).ms)
                    .slideY(begin: 0.04, end: 0);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPoint(
    BuildContext context,
    CulturalMapPoint point,
    String lang,
  ) async {
    if (point.historiaArticleId != null) {
      final articles = await HistoriaRepository.loadAll();
      final article = articles.cast<HistoriaArticle?>().firstWhere(
            (item) => item?.id == point.historiaArticleId,
            orElse: () => null,
          );
      final stage = await _preHispanicStage();
      if (!context.mounted) return;
      if (article != null) {
        AppNavigation.openHistoriaArticle(
          context,
          article: article,
          allArticles: articles,
          stage: stage,
        );
        return;
      }
    }

    if (point.contentItemId != null) {
      final item = ContentRepository.findById(point.contentItemId!);
      if (!context.mounted) return;
      if (item != null) {
        AppNavigation.openContent(context, item);
        return;
      }
    }

    // TODO: Create a dedicated article or ContentItem route for this map point.
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.marronProfundo,
        content: Text(
          context
              .read<LanguageProvider>()
              .t('cultural_map.todo_article')
              .replaceAll('{name}', point.nameFor(lang)),
          style: GoogleFonts.lato(color: AppColors.cremaPergamino),
        ),
      ),
    );
  }

  Future<HistoriaStage?> _preHispanicStage() async {
    final stages = await HistoriaStagesRepository.loadStages();
    return stages.cast<HistoriaStage?>().firstWhere(
          (stage) => stage?.id == 'peru_prehispanico',
          orElse: () => null,
        );
  }
}

class CulturalMapPoint {
  final String id;
  final Map<String, String> name;
  final Map<String, String> region;
  final Map<String, String> period;
  final String imageAsset;
  final Offset position;
  final Color accentColor;
  final String? historiaArticleId;
  final String? contentItemId;

  const CulturalMapPoint({
    required this.id,
    required this.name,
    required this.region,
    required this.period,
    required this.imageAsset,
    required this.position,
    required this.accentColor,
    this.historiaArticleId,
    this.contentItemId,
  });

  String nameFor(String lang) => name[lang] ?? name['es'] ?? id;
  String regionFor(String lang) => region[lang] ?? region['es'] ?? '';
  String periodFor(String lang) => period[lang] ?? period['es'] ?? '';
}

const culturalMapPoints = [
  CulturalMapPoint(
    id: 'caral',
    name: {'it': 'Caral', 'es': 'Caral', 'en': 'Caral'},
    region: {
      'it': 'Lima, valle di Supe',
      'es': 'Lima, valle de Supe',
      'en': 'Lima, Supe Valley'
    },
    period: {
      'it': 'Civilta arcaica',
      'es': 'Civilizacion arcaica',
      'en': 'Archaic civilization'
    },
    imageAsset: 'assets/images/caral/caral_1.jpg',
    position: Offset(0.36, 0.33),
    accentColor: AppColors.caralColor,
    historiaArticleId: 'caral',
  ),
  CulturalMapPoint(
    id: 'chavin',
    name: {'it': 'Chavin', 'es': 'Chavin', 'en': 'Chavin'},
    region: {
      'it': 'Ancash, Ande settentrionali',
      'es': 'Ancash, sierra norte',
      'en': 'Ancash, northern Andes'
    },
    period: {
      'it': 'Centro cerimoniale',
      'es': 'Centro ceremonial',
      'en': 'Ceremonial center'
    },
    imageAsset: 'assets/images/banners/sacerdote-ceremonial-andino.jpg',
    position: Offset(0.48, 0.27),
    accentColor: AppColors.worldHistoria,
    historiaArticleId: 'chavin',
  ),
  CulturalMapPoint(
    id: 'nazca',
    name: {'it': 'Nazca', 'es': 'Nazca', 'en': 'Nazca'},
    region: {
      'it': 'Ica, costa meridionale',
      'es': 'Ica, costa sur',
      'en': 'Ica, southern coast'
    },
    period: {
      'it': 'Geoglifi e deserto rituale',
      'es': 'Geoglifos y desierto ritual',
      'en': 'Geoglyphs and ritual desert'
    },
    imageAsset: 'assets/images/banners/caral-desertico.jpg',
    position: Offset(0.38, 0.55),
    accentColor: Color(0xFFD8A64A),
    historiaArticleId: 'nazca',
  ),
  CulturalMapPoint(
    id: 'moche',
    name: {'it': 'Moche', 'es': 'Moche', 'en': 'Moche'},
    region: {
      'it': 'La Libertad, costa nord',
      'es': 'La Libertad, costa norte',
      'en': 'La Libertad, northern coast'
    },
    period: {
      'it': 'Arte e potere costiero',
      'es': 'Arte y poder costero',
      'en': 'Coastal art and power'
    },
    imageAsset: 'assets/images/moche/moche_1.jpg',
    position: Offset(0.38, 0.20),
    accentColor: AppColors.mocheColor,
    contentItemId: 'moche',
  ),
  CulturalMapPoint(
    id: 'chan_chan',
    name: {'it': 'Chan Chan', 'es': 'Chan Chan', 'en': 'Chan Chan'},
    region: {
      'it': 'La Libertad, Trujillo',
      'es': 'La Libertad, Trujillo',
      'en': 'La Libertad, Trujillo'
    },
    period: {
      'it': 'Capitale Chimu',
      'es': 'Capital Chimu',
      'en': 'Chimu capital'
    },
    imageAsset: 'assets/images/moche/moche_3.jpg',
    position: Offset(0.33, 0.16),
    accentColor: Color(0xFFB86F35),
    historiaArticleId: 'chimu',
  ),
  CulturalMapPoint(
    id: 'machu_picchu',
    name: {'it': 'Machu Picchu', 'es': 'Machu Picchu', 'en': 'Machu Picchu'},
    region: {
      'it': 'Cusco, valle dell Urubamba',
      'es': 'Cusco, valle del Urubamba',
      'en': 'Cusco, Urubamba Valley'
    },
    period: {
      'it': 'Santuario inca',
      'es': 'Santuario inca',
      'en': 'Inca sanctuary'
    },
    imageAsset: 'assets/images/banners/machu-picchu-amanecer.jpg',
    position: Offset(0.60, 0.63),
    accentColor: AppColors.incaColor,
    contentItemId: 'machu_picchu',
  ),
  CulturalMapPoint(
    id: 'lago_titicaca',
    name: {'it': 'Lago Titicaca', 'es': 'Lago Titicaca', 'en': 'Lake Titicaca'},
    region: {
      'it': 'Puno, altopiano',
      'es': 'Puno, altiplano',
      'en': 'Puno, high plateau'
    },
    period: {
      'it': 'Territorio sacro andino',
      'es': 'Territorio sagrado andino',
      'en': 'Sacred Andean territory'
    },
    imageAsset: 'assets/images/tiahuanaco/tiahuanaco_2.jpg',
    position: Offset(0.70, 0.76),
    accentColor: AppColors.tiahuanacoColor,
    contentItemId: 'lago_titicaca',
  ),
  CulturalMapPoint(
    id: 'cusco',
    name: {'it': 'Cusco', 'es': 'Cusco', 'en': 'Cusco'},
    region: {
      'it': 'Cusco, Ande meridionali',
      'es': 'Cusco, Andes del sur',
      'en': 'Cusco, southern Andes'
    },
    period: {
      'it': 'Capitale del Tahuantinsuyo',
      'es': 'Capital del Tahuantinsuyo',
      'en': 'Capital of Tawantinsuyu'
    },
    imageAsset: 'assets/images/inca/inca_2.jpg',
    position: Offset(0.58, 0.58),
    accentColor: AppColors.incaColor,
    // TODO: Add a dedicated Cusco article route or ContentItem.
  ),
];

class _MapHero extends StatelessWidget {
  final String lang;

  const _MapHero({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF4A140B),
                AppColors.negoCacao,
              ],
            ),
          ),
        ),
        const CustomPaint(painter: _MuseumTexturePainter(AppColors.ocre)),
        Positioned(
          right: -22,
          top: 44,
          child: Icon(
            Icons.map_rounded,
            size: 170,
            color: AppColors.ocre.withOpacity(0.06),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 26,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 28, height: 1.5, color: AppColors.ocre),
                  const SizedBox(width: 10),
                  Text(
                    context.read<LanguageProvider>().t('cultural_map.eyebrow'),
                    style: GoogleFonts.lato(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ocre,
                      letterSpacing: 1.9,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.read<LanguageProvider>().t('cultural_map.title'),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 33,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.read<LanguageProvider>().t('cultural_map.subtitle'),
                style: GoogleFonts.lato(
                  fontSize: 13,
                  color: AppColors.cremaPergamino.withOpacity(0.68),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapStage extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onPointTap;

  const _MapStage({
    required this.selectedIndex,
    required this.onPointTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.76,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2C1810),
              Color(0xFF160B08),
            ],
          ),
          border: Border.all(color: AppColors.ocre.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ocre.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const mapInset = EdgeInsets.fromLTRB(44, 28, 44, 30);
              final mapRect = Rect.fromLTWH(
                mapInset.left,
                mapInset.top,
                constraints.maxWidth - mapInset.horizontal,
                constraints.maxHeight - mapInset.vertical,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  const CustomPaint(
                      painter: _MuseumTexturePainter(AppColors.ocre)),
                  const Padding(
                    padding: mapInset,
                    child: CustomPaint(painter: _PeruMapPainter()),
                  ),
                  ...List.generate(culturalMapPoints.length, (index) {
                    final point = culturalMapPoints[index];
                    final isSelected = selectedIndex == index;
                    return _Hotspot(
                      point: point,
                      mapRect: mapRect,
                      isSelected: isSelected,
                      onTap: () => onPointTap(index),
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    ).animate().fadeIn(duration: 520.ms).scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: 520.ms,
        );
  }
}

class _Hotspot extends StatelessWidget {
  final CulturalMapPoint point;
  final Rect mapRect;
  final bool isSelected;
  final VoidCallback onTap;

  const _Hotspot({
    required this.point,
    required this.mapRect,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 34.0 : 26.0;
    return Positioned(
      left: mapRect.left + mapRect.width * point.position.dx - size / 2,
      top: mapRect.top + mapRect.height * point.position.dy - size / 2,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: point.accentColor.withOpacity(isSelected ? 0.25 : 0.16),
            boxShadow: [
              BoxShadow(
                color: point.accentColor.withOpacity(isSelected ? 0.42 : 0.18),
                blurRadius: isSelected ? 20 : 10,
                spreadRadius: isSelected ? 4 : 1,
              ),
            ],
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: isSelected ? 15 : 10,
              height: isSelected ? 15 : 10,
              decoration: BoxDecoration(
                color: point.accentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.72)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedPointCard extends StatelessWidget {
  final CulturalMapPoint point;
  final String lang;
  final VoidCallback onOpen;

  const _SelectedPointCard({
    required this.point,
    required this.lang,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Container(
        key: ValueKey(point.id),
        decoration: BoxDecoration(
          color: AppColors.marronProfundo,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: point.accentColor.withOpacity(0.24)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ImageWithFallback(
                assetPath: point.imageAsset,
                fallbackColor: point.accentColor,
                width: 86,
                height: 92,
                fit: BoxFit.cover,
                fallbackIcon: Icon(
                  Icons.museum_rounded,
                  color: Colors.white.withOpacity(0.55),
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point.nameFor(lang),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cremaPergamino,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    point.regionFor(lang),
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: AppColors.cremaPergamino.withOpacity(0.58),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    point.periodFor(lang).toUpperCase(),
                    style: GoogleFonts.lato(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: point.accentColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onOpen,
                      style: TextButton.styleFrom(
                        foregroundColor: point.accentColor,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                      label: Text(
                        context
                            .read<LanguageProvider>()
                            .t('cultural_map.open_story'),
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

class _MapPointListTile extends StatelessWidget {
  final CulturalMapPoint point;
  final String lang;
  final bool isSelected;
  final VoidCallback onTap;

  const _MapPointListTile({
    required this.point,
    required this.lang,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? point.accentColor.withOpacity(0.13)
          : AppColors.marronProfundo,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? point.accentColor.withOpacity(0.42)
                  : AppColors.cremaPergamino.withOpacity(0.08),
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ImageWithFallback(
                  assetPath: point.imageAsset,
                  fallbackColor: point.accentColor,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  fallbackIcon: Icon(
                    Icons.place_rounded,
                    color: Colors.white.withOpacity(0.5),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.nameFor(lang),
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.cremaPergamino,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      point.regionFor(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        color: AppColors.cremaPergamino.withOpacity(0.52),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.periodFor(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: point.accentColor.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: point.accentColor.withOpacity(0.78),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: AppColors.ocre),
        const SizedBox(width: 10),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.lato(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.cremaPergamino,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

class _PeruMapPainter extends CustomPainter {
  const _PeruMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.46, size.height * 0.02)
      ..cubicTo(size.width * 0.28, size.height * 0.08, size.width * 0.25,
          size.height * 0.18, size.width * 0.22, size.height * 0.28)
      ..cubicTo(size.width * 0.18, size.height * 0.42, size.width * 0.12,
          size.height * 0.48, size.width * 0.22, size.height * 0.62)
      ..cubicTo(size.width * 0.30, size.height * 0.74, size.width * 0.45,
          size.height * 0.78, size.width * 0.54, size.height * 0.95)
      ..cubicTo(size.width * 0.62, size.height * 0.86, size.width * 0.74,
          size.height * 0.84, size.width * 0.78, size.height * 0.72)
      ..cubicTo(size.width * 0.84, size.height * 0.57, size.width * 0.74,
          size.height * 0.48, size.width * 0.73, size.height * 0.34)
      ..cubicTo(size.width * 0.72, size.height * 0.21, size.width * 0.63,
          size.height * 0.12, size.width * 0.46, size.height * 0.02)
      ..close();

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF6D351A),
          Color(0xFF9A5D26),
          Color(0xFF2D6A4F),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = AppColors.ocre.withOpacity(0.44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawShadow(path, Colors.black.withOpacity(0.45), 12, true);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);

    final coast = Paint()
      ..color = AppColors.cremaPergamino.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final coastPath = Path()
      ..moveTo(size.width * 0.34, size.height * 0.06)
      ..cubicTo(size.width * 0.22, size.height * 0.27, size.width * 0.20,
          size.height * 0.52, size.width * 0.42, size.height * 0.84);
    canvas.drawPath(coastPath, coast);

    final ridge = Paint()
      ..color = AppColors.ocre.withOpacity(0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.44 + i * 0.055);
      final wave = Path()
        ..moveTo(x, size.height * 0.14)
        ..cubicTo(x + math.sin(i) * 12, size.height * 0.34, x - 18,
            size.height * 0.55, x + 8, size.height * 0.83);
      canvas.drawPath(wave, ridge);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MuseumTexturePainter extends CustomPainter {
  final Color color;

  const _MuseumTexturePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.045)
      ..strokeWidth = 1;
    const spacing = 26.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
