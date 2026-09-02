import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigation.dart';
import '../data/content_repository.dart';
import '../data/historia_stages_repository.dart';
import '../models/historia_article.dart';
import '../models/historia_stage.dart';
import '../providers/daily_story_provider.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/image_with_fallback.dart';

class CulturalMapScreen extends StatelessWidget {
  const CulturalMapScreen({super.key});

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
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 90),
              child: CulturalMapBody(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuerpo del mapa cultural (filtro de etapa + mapa con zoom/pan + tarjeta
/// del punto seleccionado + lista), sin `Scaffold`/hero propios, para poder
/// incrustarse tanto en [CulturalMapScreen] como en la pestaña Mapa/Línea de
/// tiempo (`MapTimelineScreen`).
class CulturalMapBody extends StatefulWidget {
  const CulturalMapBody({super.key});

  @override
  State<CulturalMapBody> createState() => _CulturalMapBodyState();
}

class _CulturalMapBodyState extends State<CulturalMapBody> {
  String _stageFilter = 'all';
  int _selectedIndex = 0;

  List<CulturalMapPoint> get _visiblePoints => _stageFilter == 'all'
      ? culturalMapPoints
      : culturalMapPoints.where((p) => p.stageId == _stageFilter).toList();

  CulturalMapPoint get _selected {
    final points = _visiblePoints;
    if (points.isEmpty) return culturalMapPoints.first;
    return points[_selectedIndex.clamp(0, points.length - 1)];
  }

  void _setFilter(String stageId) {
    setState(() {
      _stageFilter = stageId;
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final points = _visiblePoints;
    final isPremium = context.watch<PremiumProvider>().isPremium;
    final dailyArticleId = context.watch<DailyStoryProvider>().dailyArticle?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<HistoriaStage>>(
          future: HistoriaStagesRepository.loadStages(),
          builder: (context, snap) {
            final stages = snap.data ?? const <HistoriaStage>[];
            return _StageFilterRow(
              stages: stages,
              activeStageId: _stageFilter,
              lang: lang,
              onSelect: _setFilter,
            );
          },
        ),
        const SizedBox(height: 18),
        _MapStage(
          points: points,
          selectedIndex: _selectedIndex,
          isPremium: isPremium,
          dailyArticleId: dailyArticleId,
          onPointTap: (index) => setState(() => _selectedIndex = index),
        ),
        const SizedBox(height: 18),
        if (points.isNotEmpty)
          _SelectedPointCard(
            point: _selected,
            lang: lang,
            isLocked: _isLocked(_selected, isPremium, dailyArticleId),
            onOpen: () => _openPoint(context, _selected, lang),
          ),
        const SizedBox(height: 28),
        _SectionTitle(label: context.read<LanguageProvider>().t('cultural_map.places')),
        const SizedBox(height: 10),
        ...List.generate(points.length, (index) {
          final point = points[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MapPointListTile(
              point: point,
              lang: lang,
              isSelected: point.id == _selected.id,
              isLocked: _isLocked(point, isPremium, dailyArticleId),
              onTap: () {
                setState(() => _selectedIndex = index);
                _openPoint(context, point, lang);
              },
            ),
          ).animate().fadeIn(duration: 380.ms, delay: (index * 35).ms);
        }),
      ],
    );
  }

  /// Un punto ligado a un capítulo respeta el mismo gating que el resto del
  /// archivo histórico (ver `AppNavigation.openHistoriaArticle`): free solo
  /// puede la Historia del Día. Uno ligado a un `ContentItem` respeta
  /// `ContentItem.isPremium`.
  bool _isLocked(CulturalMapPoint point, bool isPremium, String? dailyArticleId) {
    if (isPremium) return false;
    if (point.historiaArticleId != null) {
      return point.historiaArticleId != dailyArticleId;
    }
    if (point.contentItemId != null) {
      final item = ContentRepository.findById(point.contentItemId!);
      return item?.isPremium ?? false;
    }
    return false;
  }

  Future<void> _openPoint(
    BuildContext context,
    CulturalMapPoint point,
    String lang,
  ) async {
    if (point.historiaArticleId != null) {
      final stageId = point.stageId ?? 'peru_prehispanico';
      final stage = await _stageById(stageId);
      final articles =
          await HistoriaStagesRepository.loadArticlesForStage(stageId);
      final article = articles.cast<HistoriaArticle?>().firstWhere(
            (item) => item?.id == point.historiaArticleId,
            orElse: () => null,
          );
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
        final isPremium = context.read<PremiumProvider>().isPremium;
        AppNavigation.openContent(
          context,
          item,
          isLocked: item.isPremium && !isPremium,
        );
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

  Future<HistoriaStage?> _stageById(String id) async {
    final stages = await HistoriaStagesRepository.loadStages();
    return stages.cast<HistoriaStage?>().firstWhere(
          (stage) => stage?.id == id,
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
  final String? stageId;
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
    this.stageId,
    this.historiaArticleId,
    this.contentItemId,
  });

  String nameFor(String lang) => name[lang] ?? name['es'] ?? id;
  String regionFor(String lang) => region[lang] ?? region['es'] ?? '';
  String periodFor(String lang) => period[lang] ?? period['es'] ?? '';
}

const culturalMapPoints = [
  // ── Perú prehispánico ────────────────────────────────────────────────────
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
    stageId: 'peru_prehispanico',
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
    stageId: 'peru_prehispanico',
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
    stageId: 'peru_prehispanico',
    historiaArticleId: 'nazca',
  ),
  CulturalMapPoint(
    id: 'paracas',
    name: {'it': 'Paracas', 'es': 'Paracas', 'en': 'Paracas'},
    region: {
      'it': 'Ica, penisola desertica',
      'es': 'Ica, península desértica',
      'en': 'Ica, desert peninsula'
    },
    period: {
      'it': 'Tessitori e chirurghi',
      'es': 'Tejedores y cirujanos',
      'en': 'Weavers and surgeons'
    },
    imageAsset: 'assets/images/banners/caral-desertico.jpg',
    position: Offset(0.34, 0.50),
    accentColor: Color(0xFF4A9494),
    stageId: 'peru_prehispanico',
    historiaArticleId: 'paracas',
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
    stageId: 'peru_prehispanico',
    contentItemId: 'moche',
  ),
  CulturalMapPoint(
    id: 'wari',
    name: {'it': 'Wari', 'es': 'Wari', 'en': 'Wari'},
    region: {
      'it': 'Ayacucho, Ande centrali',
      'es': 'Ayacucho, sierra central',
      'en': 'Ayacucho, central Andes'
    },
    period: {
      'it': 'Primo impero andino',
      'es': 'Primer imperio andino',
      'en': 'First Andean empire'
    },
    imageAsset: 'assets/images/banners/sacerdote-ceremonial-andino.jpg',
    position: Offset(0.52, 0.48),
    accentColor: Color(0xFF8B5B8B),
    stageId: 'peru_prehispanico',
    historiaArticleId: 'wari',
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
    stageId: 'peru_prehispanico',
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
    stageId: 'peru_prehispanico',
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
    stageId: 'peru_prehispanico',
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
    stageId: 'peru_prehispanico',
    // TODO: Add a dedicated Cusco article route or ContentItem.
  ),

  // ── Conquista española ───────────────────────────────────────────────────
  CulturalMapPoint(
    id: 'captura_cajamarca',
    name: {
      'it': 'Cajamarca',
      'es': 'Cajamarca',
      'en': 'Cajamarca',
    },
    region: {
      'it': 'Cajamarca, Ande settentrionali',
      'es': 'Cajamarca, sierra norte',
      'en': 'Cajamarca, northern Andes'
    },
    period: {
      'it': "L'imboscata e il riscatto d'oro",
      'es': 'La emboscada y el rescate de oro',
      'en': 'The ambush and the gold ransom'
    },
    imageAsset: 'assets/images/incas/incas_1.jpg',
    position: Offset(0.42, 0.13),
    accentColor: AppColors.conquistaColor,
    stageId: 'conquista_spagnola',
    historiaArticleId: 'captura_cajamarca',
  ),
  CulturalMapPoint(
    id: 'guerra_civil_inca',
    name: {
      'it': 'Guerra civile inca',
      'es': 'Guerra civil inca',
      'en': 'Inca civil war',
    },
    region: {
      'it': 'Ande centrali',
      'es': 'Andes centrales',
      'en': 'Central Andes'
    },
    period: {
      'it': 'Huascar contro Atahualpa',
      'es': 'Huáscar contra Atahualpa',
      'en': 'Huáscar against Atahualpa'
    },
    imageAsset: 'assets/images/incas/incas_2.jpg',
    position: Offset(0.55, 0.50),
    accentColor: AppColors.conquistaColor,
    stageId: 'conquista_spagnola',
    historiaArticleId: 'guerra_civil_inca',
  ),
  CulturalMapPoint(
    id: 'resistencia_vilcabamba',
    name: {
      'it': 'Vilcabamba',
      'es': 'Vilcabamba',
      'en': 'Vilcabamba',
    },
    region: {
      'it': 'Cusco, selva andina',
      'es': 'Cusco, selva andina',
      'en': 'Cusco, Andean jungle'
    },
    period: {
      'it': "L'ultimo rifugio inca",
      'es': 'El último refugio inca',
      'en': 'The last Inca refuge'
    },
    imageAsset: 'assets/images/incas/incas_2.jpg',
    position: Offset(0.62, 0.68),
    accentColor: AppColors.conquistaColor,
    stageId: 'conquista_spagnola',
    historiaArticleId: 'resistencia_vilcabamba',
  ),

  // ── Virreinato del Perú ──────────────────────────────────────────────────
  CulturalMapPoint(
    id: 'lima_virreinal',
    name: {
      'it': 'Lima virreale',
      'es': 'Lima virreinal',
      'en': 'Viceregal Lima',
    },
    region: {
      'it': 'Lima, costa centrale',
      'es': 'Lima, costa central',
      'en': 'Lima, central coast'
    },
    period: {
      'it': 'Capitale del vicereame',
      'es': 'Capital del virreinato',
      'en': 'Viceroyalty capital'
    },
    imageAsset: 'assets/images/banners/sacerdote-ceremonial-andino.jpg',
    position: Offset(0.30, 0.45),
    accentColor: AppColors.virreinatoColor,
    stageId: 'vicereame_peru',
    historiaArticleId: 'lima_virreinal',
  ),
  CulturalMapPoint(
    id: 'sincretismo_escuela_cusquena',
    name: {
      'it': 'Escuela Cusqueña',
      'es': 'Escuela Cusqueña',
      'en': 'Cusco School',
    },
    region: {
      'it': 'Cusco, Ande meridionali',
      'es': 'Cusco, Andes del sur',
      'en': 'Cusco, southern Andes'
    },
    period: {
      'it': 'Sincretismo artistico',
      'es': 'Sincretismo artístico',
      'en': 'Artistic syncretism'
    },
    imageAsset: 'assets/images/banners/caral-desertico.jpg',
    position: Offset(0.56, 0.62),
    accentColor: AppColors.virreinatoColor,
    stageId: 'vicereame_peru',
    historiaArticleId: 'sincretismo_escuela_cusquena',
  ),
  CulturalMapPoint(
    id: 'terremoto_tapadas_limenas',
    name: {
      'it': 'Terremoto e tapadas',
      'es': 'Terremoto y tapadas',
      'en': 'Earthquake and tapadas',
    },
    region: {
      'it': 'Lima, costa centrale',
      'es': 'Lima, costa central',
      'en': 'Lima, central coast'
    },
    period: {
      'it': 'Ricostruzione e vita limena',
      'es': 'Reconstrucción y vida limeña',
      'en': 'Rebuilding and life in Lima'
    },
    imageAsset: 'assets/images/virreinato/virreinato_3.jpg',
    position: Offset(0.28, 0.50),
    accentColor: AppColors.virreinatoColor,
    stageId: 'vicereame_peru',
    historiaArticleId: 'terremoto_tapadas_limeñas',
  ),

  // ── Independencia del Perú ───────────────────────────────────────────────
  CulturalMapPoint(
    id: 'rebelion_tupac_amaru',
    name: {
      'it': 'Ribellione di Túpac Amaru II',
      'es': 'Rebelión de Túpac Amaru II',
      'en': 'Túpac Amaru II rebellion',
    },
    region: {
      'it': 'Cusco, Tinta',
      'es': 'Cusco, Tinta',
      'en': 'Cusco, Tinta'
    },
    period: {
      'it': 'La grande ribellione andina',
      'es': 'La gran rebelión andina',
      'en': 'The great Andean uprising'
    },
    imageAsset: 'assets/images/independencia/independencia_1.jpg',
    position: Offset(0.60, 0.55),
    accentColor: AppColors.independenciaColor,
    stageId: 'indipendenza',
    historiaArticleId: 'rebelion_tupac_amaru',
  ),
  CulturalMapPoint(
    id: 'corriente_libertadora_sur',
    name: {
      'it': 'Spedizione liberatrice del sud',
      'es': 'Expedición Libertadora del Sur',
      'en': 'Liberating Expedition of the South',
    },
    region: {
      'it': 'Ica, baia di Paracas',
      'es': 'Ica, bahía de Paracas',
      'en': 'Ica, Paracas Bay'
    },
    period: {
      'it': "Lo sbarco di San Martín",
      'es': 'El desembarco de San Martín',
      'en': "San Martín's landing"
    },
    imageAsset: 'assets/images/independencia/independencia_2.jpg',
    position: Offset(0.36, 0.53),
    accentColor: AppColors.independenciaColor,
    stageId: 'indipendenza',
    historiaArticleId: 'corriente_libertadora_sur',
  ),
  CulturalMapPoint(
    id: 'batallas_junin_ayacucho',
    name: {
      'it': 'Junín e Ayacucho',
      'es': 'Junín y Ayacucho',
      'en': 'Junín and Ayacucho',
    },
    region: {
      'it': 'Ande centro-meridionali',
      'es': 'Sierra centro-sur',
      'en': 'South-central highlands'
    },
    period: {
      'it': 'Le battaglie decisive',
      'es': 'Las batallas decisivas',
      'en': 'The decisive battles'
    },
    imageAsset: 'assets/images/independencia/independencia_3.jpg',
    position: Offset(0.50, 0.46),
    accentColor: AppColors.independenciaColor,
    stageId: 'indipendenza',
    historiaArticleId: 'batallas_junin_ayacucho',
  ),

  // ── República del Perú ───────────────────────────────────────────────────
  CulturalMapPoint(
    id: 'era_guano_dos_mayo',
    name: {
      'it': "Combattimento del 2 maggio",
      'es': 'Combate del 2 de Mayo',
      'en': 'Battle of May 2nd',
    },
    region: {
      'it': 'Callao, costa centrale',
      'es': 'Callao, costa central',
      'en': 'Callao, central coast'
    },
    period: {
      'it': "L'era del guano",
      'es': 'La era del guano',
      'en': 'The guano era'
    },
    imageAsset: 'assets/images/republica/republica_1.jpg',
    position: Offset(0.25, 0.40),
    accentColor: AppColors.republicaColor,
    stageId: 'republica_peru',
    historiaArticleId: 'era_guano_dos_mayo',
  ),
  CulturalMapPoint(
    id: 'guerra_pacifico_grau',
    name: {
      'it': 'Guerra del Pacifico',
      'es': 'Guerra del Pacífico',
      'en': 'War of the Pacific',
    },
    region: {
      'it': 'Costa meridionale',
      'es': 'Costa sur',
      'en': 'Southern coast'
    },
    period: {
      'it': "L'eroismo di Grau",
      'es': 'El heroísmo de Grau',
      'en': "Grau's heroism"
    },
    imageAsset: 'assets/images/republica/republica_2.jpg',
    position: Offset(0.20, 0.80),
    accentColor: AppColors.republicaColor,
    stageId: 'republica_peru',
    historiaArticleId: 'guerra_pacifico_grau',
  ),
  CulturalMapPoint(
    id: 'resistencia_bolognesi_caceres',
    name: {
      'it': 'Resistenza di Bolognesi e Cáceres',
      'es': 'Resistencia de Bolognesi y Cáceres',
      'en': 'Bolognesi and Cáceres resistance',
    },
    region: {
      'it': 'Frontiera meridionale',
      'es': 'Frontera sur',
      'en': 'Southern border'
    },
    period: {
      'it': 'La resistencia final',
      'es': 'La resistencia final',
      'en': 'The final resistance'
    },
    imageAsset: 'assets/images/republica/republica_3.jpg',
    position: Offset(0.24, 0.88),
    accentColor: AppColors.republicaColor,
    stageId: 'republica_peru',
    historiaArticleId: 'resistencia_bolognesi_caceres',
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
            color: AppColors.ocre.withValues(alpha: 0.06),
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
                  color: AppColors.cremaPergamino.withValues(alpha: 0.68),
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

// ── Filtro por etapa ────────────────────────────────────────────────────────

class _StageFilterRow extends StatelessWidget {
  final List<HistoriaStage> stages;
  final String activeStageId;
  final String lang;
  final ValueChanged<String> onSelect;

  const _StageFilterRow({
    required this.stages,
    required this.activeStageId,
    required this.lang,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.read<LanguageProvider>();
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: t.t('cultural_map.filter_all'),
            color: AppColors.ocre,
            isActive: activeStageId == 'all',
            onTap: () => onSelect('all'),
          ),
          ...stages.map(
            (stage) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _FilterChip(
                label: stage.tituloFor(lang),
                color: stage.accentColor,
                isActive: activeStageId == stage.id,
                onTap: () => onSelect(stage.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.2) : AppColors.marronProfundo,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.7) : AppColors.cremaPergamino.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? color : AppColors.cremaPergamino.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mapa con zoom/pan ────────────────────────────────────────────────────────

class _MapStage extends StatelessWidget {
  final List<CulturalMapPoint> points;
  final int selectedIndex;
  final bool isPremium;
  final String? dailyArticleId;
  final ValueChanged<int> onPointTap;

  const _MapStage({
    required this.points,
    required this.selectedIndex,
    required this.isPremium,
    required this.dailyArticleId,
    required this.onPointTap,
  });

  bool _isLocked(CulturalMapPoint point) {
    if (isPremium || point.historiaArticleId == null) return false;
    return point.historiaArticleId != dailyArticleId;
  }

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
          border: Border.all(color: AppColors.ocre.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ocre.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            boundaryMargin: const EdgeInsets.all(40),
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
                    ...List.generate(points.length, (index) {
                      final point = points[index];
                      final isSelected = selectedIndex == index;
                      return _Hotspot(
                        point: point,
                        mapRect: mapRect,
                        isSelected: isSelected,
                        isLocked: _isLocked(point),
                        onTap: () => onPointTap(index),
                      );
                    }),
                  ],
                );
              },
            ),
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
  final bool isLocked;
  final VoidCallback onTap;

  const _Hotspot({
    required this.point,
    required this.mapRect,
    required this.isSelected,
    required this.isLocked,
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
            color: point.accentColor.withValues(alpha: isSelected ? 0.25 : 0.16),
            boxShadow: [
              BoxShadow(
                color: point.accentColor.withValues(alpha: isSelected ? 0.42 : 0.18),
                blurRadius: isSelected ? 20 : 10,
                spreadRadius: isSelected ? 4 : 1,
              ),
            ],
          ),
          child: Center(
            child: isLocked
                ? Icon(Icons.lock_rounded,
                    size: isSelected ? 15 : 11, color: Colors.white.withValues(alpha: 0.85))
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    width: isSelected ? 15 : 10,
                    height: isSelected ? 15 : 10,
                    decoration: BoxDecoration(
                      color: point.accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
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
  final bool isLocked;
  final VoidCallback onOpen;

  const _SelectedPointCard({
    required this.point,
    required this.lang,
    required this.isLocked,
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
          border: Border.all(color: point.accentColor.withValues(alpha: 0.24)),
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
                  color: Colors.white.withValues(alpha: 0.55),
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
                      color: AppColors.cremaPergamino.withValues(alpha: 0.58),
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
                      icon: Icon(
                        isLocked
                            ? Icons.lock_rounded
                            : Icons.arrow_forward_rounded,
                        size: 15,
                      ),
                      label: Text(
                        context.read<LanguageProvider>().t(
                              isLocked
                                  ? 'premium.locked_label'
                                  : 'cultural_map.open_story',
                            ),
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
  final bool isLocked;
  final VoidCallback onTap;

  const _MapPointListTile({
    required this.point,
    required this.lang,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? point.accentColor.withValues(alpha: 0.13)
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
                  ? point.accentColor.withValues(alpha: 0.42)
                  : AppColors.cremaPergamino.withValues(alpha: 0.08),
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
                    color: Colors.white.withValues(alpha: 0.5),
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
                        color: AppColors.cremaPergamino.withValues(alpha: 0.52),
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
                        color: point.accentColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isLocked ? Icons.lock_rounded : Icons.arrow_forward_ios_rounded,
                size: 13,
                color: point.accentColor.withValues(alpha: 0.78),
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
      ..color = AppColors.ocre.withValues(alpha: 0.44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.45), 12, true);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);

    final coast = Paint()
      ..color = AppColors.cremaPergamino.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final coastPath = Path()
      ..moveTo(size.width * 0.34, size.height * 0.06)
      ..cubicTo(size.width * 0.22, size.height * 0.27, size.width * 0.20,
          size.height * 0.52, size.width * 0.42, size.height * 0.84);
    canvas.drawPath(coastPath, coast);

    final ridge = Paint()
      ..color = AppColors.ocre.withValues(alpha: 0.16)
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
      ..color = color.withValues(alpha: 0.045)
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
