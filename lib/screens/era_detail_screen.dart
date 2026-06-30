import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_config.dart';
import '../models/era_model.dart';
import '../models/wikipedia_content.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import '../providers/language_provider.dart';
import '../data/editorial_repository.dart';
import '../models/editorial_content.dart';
import '../services/wikipedia_service.dart';
import '../widgets/caral_hero_carousel.dart';
import '../widgets/caral_placeholder.dart';
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
  bool _wikiFailed = false;
  String? _lastLoadedLang;
  bool _isEditorial = false;
  String? _editorialFuente;

  // Pinch-to-zoom for Resumen and Contenido tabs
  final TransformationController _txController = TransformationController();
  double _textScale = 1.0;
  double _baseTextScale = 1.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _textScale = 1.0);
      }
    });
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
    // Track in history (once)
    if (_lastLoadedLang != null) {
      context.read<HistoryProvider>().add(widget.era.id);
    }
  }

  Future<void> _loadWikipediaContent(String lang) async {
    setState(() {
      _isLoadingWiki = true;
      _wikiContent = null;
      _wikiFailed = false;
      _isEditorial = false;
      _editorialFuente = null;
    });

    // Try local editorial content first; no network needed.
    final EditorialContent? editorial = await EditorialRepository.findById(
      widget.era.id,
      'era',
    );

    if (editorial != null) {
      final sections =
          WikipediaContent.parseSections(editorial.contenidoFor(lang));
      if (mounted) {
        setState(() {
          _wikiContent = WikipediaContent(
            title: editorial.tituloFor(lang),
            sections: sections,
            sourceUrl: '',
            cachedAt: DateTime.now(),
            displayLang: lang,
          );
          _isLoadingWiki = false;
          _isEditorial = true;
          _editorialFuente = editorial.fuenteFor(lang);
        });
      }
      return;
    }

    // Fallback: Wikipedia remote fetch.
    if (!AppConfig.enableWikipediaFallback ||
        widget.era.wikipediaSlug.isEmpty) {
      if (mounted) setState(() => _isLoadingWiki = false);
      return;
    }

    final content = await WikipediaService.instance.fetch(
      contentId: widget.era.id,
      lang: lang,
      slugMap: widget.era.wikipediaSlug,
    );

    if (mounted) {
      setState(() {
        _wikiContent = content;
        _isLoadingWiki = false;
        _wikiFailed = content == null;
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
            _buildResumenTab(t, lang),
            _buildContenidoTab(t, lang),
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
      actions: [
        _FavoriteButton(itemId: widget.era.id),
        const LanguageSelectorButton(),
      ],
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
              // Caral no tiene fotografía: usamos un fallback artístico en
              // lugar del placeholder genérico para no romper la estética.
              fallbackOverride: widget.era.id == 'caral'
                  ? CaralPlaceholder(accentColor: widget.era.accentColor)
                  : null,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  // ── Tab 1: Resumen ────────────────────────────────────────────────────────

  Widget _buildResumenTab(String Function(String) t, String lang) {
    return _wrapWithZoom(
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: _buildResumenContent(t, lang)
            .animate()
            .fadeIn(duration: 500.ms, delay: 80.ms),
      ),
    );
  }

  Widget _buildResumenContent(String Function(String) t, String lang) {
    // Loading state
    if (_isLoadingWiki) {
      return Column(
        children: [
          const SizedBox(height: 8),
          WikipediaSectionWidget(
            content: null,
            isLoading: true,
            accentColor: widget.era.accentColor,
            languageCode: lang,
          ),
        ],
      );
    }

    // Error state — no content at all
    if (_wikiFailed && _wikiContent == null) {
      return WikipediaSectionWidget(
        content: null,
        isLoading: false,
        hasFailed: true,
        onRetry: () => _loadWikipediaContent(lang),
        accentColor: widget.era.accentColor,
        languageCode: lang,
      );
    }

    final content = _wikiContent;

    // Fallback to translation description when no Wikipedia content
    if (content == null || !content.hasContent) {
      return _buildFallbackResumen(t, lang);
    }

    final lead = content.leadSection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero carousel — solo Caral, solo contenido editorial
        if (widget.era.id == 'caral' && _isEditorial) ...[
          const CaralHeroCarousel(),
          const SizedBox(height: 20),
        ],

        // Offline badge
        if (content.isFromCache) ...[
          _buildOfflineCard(lang),
          const SizedBox(height: 14),
        ],

        // Wikipedia thumbnail
        if (content.hasThumbnail) ...[
          _buildHeroThumbnail(content.thumbnailUrl!),
          const SizedBox(height: 20),
        ],

        // Lead paragraph card
        if (lead != null) _buildLeadCard(lead.content, lang),

        const SizedBox(height: 20),

        // Source + read more (Wikipedia) or editorial attribution
        if (_isEditorial)
          _buildEditorialAttribution()
        else ...[
          _buildReadMoreButton(content.sourceUrl, lang),
          const SizedBox(height: 12),
          _buildSourceAttribution(content, lang),
        ],
      ],
    );
  }

  Widget _buildFallbackResumen(String Function(String) t, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.era.accentColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.era.accentColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            t('eras.${widget.era.id}.description'),
            style: GoogleFonts.lato(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.75,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroThumbnail(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 220,
          color: widget.era.accentColor.withOpacity(0.1),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.era.accentColor,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildLeadCard(String text, String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.era.accentColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.era.accentColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 2,
                color: widget.era.accentColor,
              ),
              const SizedBox(width: 10),
              Text(
                context.read<LanguageProvider>().t('wikipedia.overview'),
                style: GoogleFonts.lato(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: widget.era.accentColor,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            text,
            style: GoogleFonts.lato(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineCard(String lang) {
    final label = context.read<LanguageProvider>().t('wikipedia.cached');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 14, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 12,
                color: Colors.orange.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadMoreButton(String url, String lang) {
    final label = context.read<LanguageProvider>().t('wikipedia.read_more');
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _launchUrl(url),
        icon: Icon(Icons.open_in_new_rounded,
            size: 16, color: widget.era.accentColor),
        label: Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: widget.era.accentColor,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: widget.era.accentColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceAttribution(WikipediaContent content, String lang) {
    final isFallback =
        content.displayLang.isNotEmpty && content.displayLang != lang;
    final langLabel =
        (content.displayLang.isNotEmpty ? content.displayLang : lang)
            .toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dividerColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                "${context.read<LanguageProvider>().t('wikipedia.source')}: Wikipedia $langLabel - ",
                style: GoogleFonts.lato(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
              Flexible(
                child: Text(
                  content.title,
                  style: GoogleFonts.lato(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (isFallback) ...[
            const SizedBox(height: 3),
            Text(
              "${context.read<LanguageProvider>().t('wikipedia.content_available_in')}: $langLabel",
              style: GoogleFonts.lato(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Contenido ──────────────────────────────────────────────────────

  Widget _buildContenidoTab(String Function(String) t, String lang) {
    final child = _isEditorial
        ? _buildEditorialContenido()
        : WikipediaSectionWidget(
            content: _wikiContent,
            isLoading: _isLoadingWiki,
            hasFailed: _wikiFailed && _wikiContent == null,
            onRetry: () => _loadWikipediaContent(lang),
            accentColor: widget.era.accentColor,
            languageCode: lang,
            hideLeadSection: true,
            fallbackDescription: null,
          );

    return _wrapWithZoom(
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: child.animate().fadeIn(duration: 500.ms, delay: 80.ms),
      ),
    );
  }

  // ── Editorial renderers ───────────────────────────────────────────────────

  Widget _buildEditorialContenido() {
    final content = _wikiContent;
    if (content == null || !content.hasContent) return const SizedBox.shrink();

    final sections = content.contentSections;
    final isCaral = widget.era.id == 'caral';

    final children = <Widget>[const SizedBox(height: 16)];

    for (int i = 0; i < sections.length; i++) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Text(
          sections[i].content,
          style: GoogleFonts.lato(
            fontSize: 15,
            color: AppColors.textPrimary,
            height: 1.8,
          ),
        ),
      ));

      // Imagen intermedia después del 3er párrafo (índice 2)
      if (isCaral && i == 2) {
        children.add(_buildCaralInlineImage(
          'assets/images/content/caral/plaza_circular_caral.webp',
        ));
      }
    }

    // Imagen final contemplativa (solo Caral)
    if (isCaral) {
      children.add(_buildCaralInlineImage(
        'assets/images/content/caral/caral_atardecer_eterno.webp',
      ));
    }

    children.add(const SizedBox(height: 8));
    children.add(_buildEditorialAttribution());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildCaralInlineImage(String assetPath) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 220,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorialAttribution() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dividerColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book_outlined,
              size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _editorialFuente ?? '',
              style: GoogleFonts.lato(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Galería ────────────────────────────────────────────────────────

  Widget _buildGaleriaTab(BuildContext context) {
    final images = widget.era.imageFilenames;
    final hasWikiThumb = _wikiContent?.hasThumbnail == true && !_isLoadingWiki;
    final totalItems = images.length + (hasWikiThumb ? 1 : 0);

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // Wikipedia thumbnail as the last grid item
        if (hasWikiThumb && index == images.length) {
          return _buildWikiGridThumb(_wikiContent!.thumbnailUrl!)
              .animate()
              .fadeIn(duration: 400.ms, delay: (index * 60).ms);
        }

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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                      '',
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

  Widget _buildWikiGridThumb(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: widget.era.accentColor.withOpacity(0.1),
            ),
            errorWidget: (_, __, ___) => Container(
              color: widget.era.accentColor.withOpacity(0.1),
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '',
                style: GoogleFonts.lato(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pinch-to-zoom ─────────────────────────────────────────────────────────

  Widget _wrapWithZoom(Widget child) {
    return InteractiveViewer(
      panEnabled: false,
      scaleEnabled: true,
      minScale: 0.5,
      maxScale: 8.0,
      transformationController: _txController,
      onInteractionStart: (_) => _baseTextScale = _textScale,
      onInteractionUpdate: (details) {
        final newScale = (_baseTextScale * details.scale).clamp(0.8, 3.0);
        if ((newScale - _textScale).abs() > 0.005) {
          setState(() => _textScale = newScale);
        }
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
    return [
      context.read<LanguageProvider>().t('wikipedia.overview'),
      context.read<LanguageProvider>().t('wikipedia.content'),
      context.read<LanguageProvider>().t('wikipedia.gallery')
    ];
  }
}

// ── Favorite button ───────────────────────────────────────────────────────────

class _FavoriteButton extends StatelessWidget {
  final String itemId;
  const _FavoriteButton({required this.itemId});

  @override
  Widget build(BuildContext context) {
    final isFav = context.watch<FavoritesProvider>().isFavorite(itemId);
    return IconButton(
      icon: Icon(
        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isFav ? Colors.redAccent : AppColors.cremaPergamino,
        size: 22,
      ),
      onPressed: () => context.read<FavoritesProvider>().toggle(itemId),
    );
  }
}

// ── TabBar persistent header delegate ─────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color color;
  static const double _height = 46;

  const _TabBarDelegate({required this.child, required this.color});

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: color, child: child);
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      child != old.child || color != old.color;
}
