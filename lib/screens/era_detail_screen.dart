import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../models/era_model.dart';
import '../models/europeana_item.dart';
import '../models/wikipedia_content.dart';
import '../providers/language_provider.dart';
import '../services/europeana_service.dart';
import '../services/wikipedia_service.dart';
import '../widgets/image_with_fallback.dart';
import '../widgets/language_selector_button.dart';
import '../widgets/wikipedia_section_widget.dart';
import 'gallery_screen.dart';

class EraDetailScreen extends StatefulWidget {
  final EraModel era;

  const EraDetailScreen({super.key, required this.era});

  @override
  State<EraDetailScreen> createState() => _EraDetailScreenState();
}

class _EraDetailScreenState extends State<EraDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  WikipediaContent? _wikiContent;
  bool _isLoadingWiki = false;
  String? _lastLoadedLang;

  List<EuropeanaItem> _europeanaItems = [];
  bool _isLoadingEuropeana = false;
  bool _europeanaLoaded = false;

  // Pinch-to-zoom: shared scale across Historia and Artefactos tabs
  final TransformationController _txController = TransformationController();
  double _textScale = 1.0;
  double _baseTextScale = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // Reset zoom when switching tabs for a clean reading experience
      if (_tabController.indexIsChanging) {
        setState(() => _textScale = 1.0);
      }
    });
    _loadEuropeana();
  }

  @override
  void dispose() {
    _txController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.read<LanguageProvider>().currentLanguage;
    if (lang != _lastLoadedLang) {
      _lastLoadedLang = lang;
      _loadWikipediaContent(lang);
    }
  }

  Future<void> _loadWikipediaContent(String lang) async {
    if (widget.era.wikipediaSlug.isEmpty) return;

    setState(() {
      _isLoadingWiki = true;
      _wikiContent = null;
    });

    final content = await WikipediaService.instance.fetch(
      eraId: widget.era.id,
      lang: lang,
      slugMap: widget.era.wikipediaSlug,
    );

    if (mounted) {
      setState(() {
        _wikiContent = content;
        _isLoadingWiki = false;
      });
    }
  }

  Future<void> _loadEuropeana() async {
    if (_europeanaLoaded) return;
    setState(() => _isLoadingEuropeana = true);

    final items = await EuropeanaService.instance.searchForEra(widget.era.id);

    if (mounted) {
      setState(() {
        _europeanaItems = items;
        _isLoadingEuropeana = false;
        _europeanaLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final labels = _tabLabels(lang);

    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(context, t),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              color: AppColors.bgColor,
              child: TabBar(
                controller: _tabController,
                indicatorColor: widget.era.accentColor,
                indicatorWeight: 2.5,
                labelColor: widget.era.accentColor,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: GoogleFonts.lato(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
                unselectedLabelStyle: GoogleFonts.lato(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
                tabs: labels.map((l) => Tab(text: l)).toList(),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildHistoriaTab(t, lang),
            _buildArtefactosTab(lang),
            _buildGaleriaTab(context),
          ],
        ),
      ),
    );
  }

  // ── SliverAppBar ──────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext context, String Function(String) t) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.marronOscuro,
      foregroundColor: AppColors.cremaPergamino,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.marronOscuro.withOpacity(0.7),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [const LanguageSelectorButton()],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          fit: StackFit.expand,
          children: [
            ImageWithFallback(
              assetPath:
                  widget.era.imageAssetPath(widget.era.imageFilenames.first),
              fallbackColor: widget.era.accentColor,
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.marronOscuro.withOpacity(0.85),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.era.accentColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t('eras.${widget.era.id}.period'),
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('eras.${widget.era.id}.title'),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    t('eras.${widget.era.id}.subtitle'),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.cremaPergamino.withOpacity(0.85),
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

  // ── Tab 1: Historia ───────────────────────────────────────────────────────

  Widget _buildHistoriaTab(String Function(String) t, String lang) {
    return _wrapWithZoom(
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: WikipediaSectionWidget(
          content: _wikiContent,
          isLoading: _isLoadingWiki,
          accentColor: widget.era.accentColor,
          languageCode: lang,
          fallbackDescription: t('eras.${widget.era.id}.description'),
        ).animate().fadeIn(duration: 600.ms, delay: 100.ms),
      ),
    );
  }

  // ── Tab 2: Artefactos (Europeana) ─────────────────────────────────────────

  Widget _buildArtefactosTab(String lang) {
    if (_isLoadingEuropeana) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: widget.era.accentColor,
              strokeWidth: 2,
            ),
            const SizedBox(height: 16),
            Text(
              _europeanaLoadingLabel(lang),
              style: GoogleFonts.lato(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    if (_europeanaItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.museum_rounded,
                size: 52,
                color: widget.era.accentColor.withOpacity(0.3),
              ),
              const SizedBox(height: 20),
              Text(
                _europeanaEmptyLabel(lang),
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Europeana.eu',
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: widget.era.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _wrapWithZoom(
      ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        itemCount: _europeanaItems.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == _europeanaItems.length) return _buildEuropeanaFooter(lang);
          return _buildArtefactoCard(_europeanaItems[index])
              .animate()
              .fadeIn(duration: 500.ms, delay: (index * 80).ms);
        },
      ),
    );
  }

  Widget _buildArtefactoCard(EuropeanaItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cremaPergamino,
        border: Border.all(color: AppColors.dividerColor),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.hasImage)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: item.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: widget.era.accentColor.withOpacity(0.08),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.era.accentColor,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 160,
                  color: widget.era.accentColor.withOpacity(0.08),
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textSecondary.withOpacity(0.4),
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.era.accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.era.accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📍', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Museo: ${item.institution}',
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.era.accentColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _launchUrl(item.europeanaUrl),
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new_rounded,
                          size: 13, color: widget.era.accentColor),
                      const SizedBox(width: 5),
                      Text(
                        'Ver en Europeana',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: widget.era.accentColor,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: widget.era.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEuropeanaFooter(String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Container(
            height: 1,
            color: AppColors.dividerColor.withOpacity(0.5),
            margin: const EdgeInsets.only(bottom: 12),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                _europeanaSourceLabel(lang),
                style: GoogleFonts.lato(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Galería (ilustraciones IA) ─────────────────────────────────────

  Widget _buildGaleriaTab(BuildContext context) {
    final images = widget.era.imageFilenames;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _openGallery(context, initialIndex: index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageWithFallback(
                  assetPath: widget.era.imageAssetPath(images[index]),
                  fallbackColor: widget.era.accentColor.withOpacity(0.7),
                  fit: BoxFit.cover,
                  fallbackIcon: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      '${index + 1} / ${images.length}',
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: (index * 60).ms)
            .scale(begin: const Offset(0.95, 0.95), duration: 400.ms);
      },
    );
  }

  // ── Pinch-to-zoom ─────────────────────────────────────────────────────────

  // Wraps [child] so that a two-finger pinch scales the text via textScaler
  // (text reflows at the new size) while single-finger scroll still works.
  // Strategy: InteractiveViewer detects the gesture; we extract details.scale
  // and apply it as MediaQuery.textScaler, then reset the matrix transform so
  // no pixel-scaling is applied visually.
  Widget _wrapWithZoom(Widget child) {
    return InteractiveViewer(
      panEnabled: false,
      scaleEnabled: true,
      minScale: 0.5,
      maxScale: 8.0,
      transformationController: _txController,
      onInteractionStart: (_) => _baseTextScale = _textScale,
      onInteractionUpdate: (details) {
        final newScale =
            (_baseTextScale * details.scale).clamp(0.8, 3.0);
        if ((newScale - _textScale).abs() > 0.005) {
          setState(() => _textScale = newScale);
        }
        // Reset the matrix so InteractiveViewer never pixel-scales the content.
        // Text reflow is handled by MediaQuery.textScaler below instead.
        _txController.value = Matrix4.identity();
      },
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(_textScale),
        ),
        child: child,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _openGallery(BuildContext context, {int initialIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GalleryScreen(
          era: widget.era,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<String> _tabLabels(String lang) {
    switch (lang) {
      case 'en':
        return ['HISTORY', 'ARTIFACTS', 'GALLERY'];
      case 'it':
        return ['STORIA', 'MANUFATTI', 'GALLERIA'];
      default:
        return ['HISTORIA', 'ARTEFACTOS', 'GALERÍA'];
    }
  }

  String _europeanaLoadingLabel(String lang) {
    switch (lang) {
      case 'en':
        return 'Searching Europeana museums…';
      case 'it':
        return 'Ricerca nei musei Europeana…';
      default:
        return 'Buscando en museos Europeana…';
    }
  }

  String _europeanaEmptyLabel(String lang) {
    switch (lang) {
      case 'en':
        return 'No artifacts found in Europeana for this era.';
      case 'it':
        return 'Nessun manufatto trovato su Europeana per questa era.';
      default:
        return 'No se encontraron artefactos en Europeana para esta era.';
    }
  }

  String _europeanaSourceLabel(String lang) {
    switch (lang) {
      case 'en':
        return 'Source: Europeana — European cultural heritage';
      case 'it':
        return 'Fonte: Europeana — Patrimonio culturale europeo';
      default:
        return 'Fuente: Europeana — Patrimonio cultural europeo';
    }
  }
}

// ── TabBar persistent header delegate ─────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color color;
  static const double _height = 46;

  const _TabBarDelegate({
    required this.child,
    required this.color,
  });

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: color,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) =>
      child != oldDelegate.child || color != oldDelegate.color;
}
