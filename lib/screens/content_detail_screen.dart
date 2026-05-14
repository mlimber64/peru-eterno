import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/category_config.dart';
import '../models/content_item.dart';
import '../models/wikipedia_content.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import '../providers/language_provider.dart';
import '../services/wikipedia_service.dart';
import '../widgets/language_selector_button.dart';
import '../widgets/wikipedia_section_widget.dart';

class ContentDetailScreen extends StatefulWidget {
  final ContentItem item;

  const ContentDetailScreen({super.key, required this.item});

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  WikipediaContent? _wikiContent;
  bool _isLoadingWiki = false;
  bool _wikiFailed = false;
  String? _lastLoadedLang;

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
    if (_lastLoadedLang != null) {
      context.read<HistoryProvider>().add(widget.item.id);
    }
  }

  Future<void> _loadWikipediaContent(String lang) async {
    if (widget.item.wikipediaSlug.isEmpty) return;

    setState(() {
      _isLoadingWiki = true;
      _wikiContent = null;
      _wikiFailed = false;
    });

    final content = await WikipediaService.instance.fetch(
      contentId: widget.item.id,
      lang: lang,
      slugMap: widget.item.wikipediaSlug,
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
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final labels = _tabLabels(lang);
    final color = CategoryConfigs.colorOf(widget.item.category);

    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(context, color),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              color: AppColors.bgColor,
              child: TabBar(
                controller: _tabController,
                indicatorColor: color,
                indicatorWeight: 2.5,
                labelColor: color,
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
            _buildResumenTab(lang),
            _buildContenidoTab(lang),
            _buildGaleriaTab(),
          ],
        ),
      ),
    );
  }

  // ── SliverAppBar ──────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext context, Color color) {
    final icon = CategoryConfigs.iconOf(widget.item.category);

    return SliverAppBar(
      expandedHeight: 260,
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
        _FavButton(itemId: widget.item.id),
        const LanguageSelectorButton(),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Category gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.9),
                    color.withOpacity(0.6),
                    AppColors.marronOscuro,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Large background icon
            Positioned(
              right: -20,
              top: 20,
              child: Icon(
                icon,
                size: 180,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
            // Wikipedia thumbnail if available
            if (_wikiContent?.hasThumbnail == true)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: _wikiContent!.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            // Gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.marronOscuro.withOpacity(0.9),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            // Title area
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
                      color: color.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 11, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          CategoryConfigs.labelOf(
                            widget.item.category,
                            _lastLoadedLang ?? 'es',
                          ).toUpperCase(),
                          style: GoogleFonts.lato(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.item.displayName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildResumenTab(String lang) {
    final color = CategoryConfigs.colorOf(widget.item.category);

    return _wrapWithZoom(
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: _buildResumenContent(lang, color)
            .animate()
            .fadeIn(duration: 500.ms, delay: 80.ms),
      ),
    );
  }

  Widget _buildResumenContent(String lang, Color color) {
    if (_isLoadingWiki) {
      return WikipediaSectionWidget(
        content: null,
        isLoading: true,
        accentColor: color,
        languageCode: lang,
      );
    }

    if (_wikiFailed && _wikiContent == null) {
      return WikipediaSectionWidget(
        content: null,
        isLoading: false,
        hasFailed: true,
        onRetry: () => _loadWikipediaContent(lang),
        accentColor: color,
        languageCode: lang,
      );
    }

    final content = _wikiContent;
    if (content == null || !content.hasContent) {
      return _buildNoContentPlaceholder(color);
    }

    final lead = content.leadSection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content.isFromCache) ...[
          _buildOfflineCard(lang),
          const SizedBox(height: 14),
        ],
        if (content.hasThumbnail) ...[
          _buildHeroThumbnail(content.thumbnailUrl!, color),
          const SizedBox(height: 20),
        ],
        if (lead != null) _buildLeadCard(lead.content, color),
        const SizedBox(height: 20),
        _buildReadMoreButton(content.sourceUrl, lang, color),
        const SizedBox(height: 12),
        _buildSourceAttribution(content, lang),
      ],
    );
  }

  Widget _buildNoContentPlaceholder(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            CategoryConfigs.iconOf(widget.item.category),
            size: 48,
            color: color.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            widget.item.displayName,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroThumbnail(String url, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 220,
          color: color.withOpacity(0.1),
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
        ),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildLeadCard(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 28, height: 2, color: color),
              const SizedBox(width: 10),
              Text(
                'RESUMEN',
                style: GoogleFonts.lato(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
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
    final label = switch (lang) {
      'en' => 'Showing cached content — connect to update',
      'it' => 'Contenuto dalla cache — connettiti per aggiornare',
      _ => 'Contenido sin conexión — conéctate para actualizar',
    };
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

  Widget _buildReadMoreButton(String url, String lang, Color color) {
    final label = switch (lang) {
      'en' => 'Read more on Wikipedia',
      'it' => 'Leggi di più su Wikipedia',
      _ => 'Leer más en Wikipedia',
    };
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _launchUrl(url),
        icon: Icon(Icons.open_in_new_rounded, size: 16, color: color),
        label: Text(
          label,
          style: GoogleFonts.lato(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: color, width: 1.5),
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
                'Fuente: Wikipedia $langLabel — ',
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
              'Contenido disponible en: $langLabel',
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

  Widget _buildContenidoTab(String lang) {
    final color = CategoryConfigs.colorOf(widget.item.category);

    return _wrapWithZoom(
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: WikipediaSectionWidget(
          content: _wikiContent,
          isLoading: _isLoadingWiki,
          hasFailed: _wikiFailed && _wikiContent == null,
          onRetry: () => _loadWikipediaContent(lang),
          accentColor: color,
          languageCode: lang,
          hideLeadSection: true,
          fallbackDescription: null,
        ).animate().fadeIn(duration: 500.ms, delay: 80.ms),
      ),
    );
  }

  // ── Tab 3: Galería ────────────────────────────────────────────────────────

  Widget _buildGaleriaTab() {
    final color = CategoryConfigs.colorOf(widget.item.category);
    final icon = CategoryConfigs.iconOf(widget.item.category);
    final hasThumb = _wikiContent?.hasThumbnail == true && !_isLoadingWiki;

    if (!hasThumb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color.withOpacity(0.25)),
            const SizedBox(height: 16),
            Text(
              widget.item.displayName,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.count(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildWikiThumb(_wikiContent!.thumbnailUrl!, color),
      ],
    );
  }

  Widget _buildWikiThumb(String url, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                Container(color: color.withOpacity(0.1)),
            errorWidget: (_, __, ___) => Container(
              color: color.withOpacity(0.1),
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Wiki',
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
    ).animate().fadeIn(duration: 400.ms);
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
        final newScale =
            (_baseTextScale * details.scale).clamp(0.8, 3.0);
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<String> _tabLabels(String lang) {
    return switch (lang) {
      'en' => ['OVERVIEW', 'CONTENT', 'GALLERY'],
      'it' => ['PANORAMICA', 'CONTENUTO', 'GALLERIA'],
      _ => ['RESUMEN', 'CONTENIDO', 'GALERÍA'],
    };
  }
}

// ── Favorite button ───────────────────────────────────────────────────────────

class _FavButton extends StatelessWidget {
  final String itemId;
  const _FavButton({required this.itemId});

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

// ── TabBar persistent header delegate ────────────────────────────────────────

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
