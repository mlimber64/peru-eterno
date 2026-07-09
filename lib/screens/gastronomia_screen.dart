import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/world_config.dart';
import '../models/editorial_content.dart';
import '../providers/content_provider.dart';
import '../providers/language_provider.dart';

/// Pantalla de Gastronomía servida **desde Supabase** (vía [ContentProvider])
/// con caché offline-first. Demuestra la cadena completa:
/// Supabase → caché sqflite → repositorio → provider → UI.
class GastronomiaScreen extends StatefulWidget {
  const GastronomiaScreen({super.key});

  static const category = 'gastronomia';

  @override
  State<GastronomiaScreen> createState() => _GastronomiaScreenState();
}

class _GastronomiaScreenState extends State<GastronomiaScreen> {
  @override
  void initState() {
    super.initState();
    // Dispara la carga tras el primer frame (no en build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContentProvider>().ensureLoaded(GastronomiaScreen.category);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final content = context.watch<ContentProvider>();
    final items = content.itemsFor(GastronomiaScreen.category);
    final world = WorldConfig.findById('sabores');
    final accent = world?.accentColor ?? AppColors.worldSabores;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      appBar: AppBar(
        backgroundColor: AppColors.negoCacao,
        foregroundColor: AppColors.cremaPergamino,
        title: Text(
          world?.titleFor(lang) ?? 'Gastronomía',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
      ),
      body: content.isLoading(GastronomiaScreen.category)
          ? Center(child: CircularProgressIndicator(color: accent))
          : RefreshIndicator(
              color: accent,
              backgroundColor: AppColors.marronProfundo,
              onRefresh: () =>
                  content.refresh(GastronomiaScreen.category),
              child: CustomScrollView(
                slivers: [
                  if (content.isOffline(GastronomiaScreen.category))
                    SliverToBoxAdapter(child: _OfflineBanner(accent: accent)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _DishCard(
                          item: items[i],
                          lang: lang,
                          accent: accent,
                        ),
                        childCount: items.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final Color accent;
  const _OfflineBanner({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.read<LanguageProvider>().t('states.offline_cached'),
              style: GoogleFonts.lato(
                fontSize: 12,
                color: AppColors.cremaPergamino.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  final EditorialContent item;
  final String lang;
  final Color accent;
  const _DishCard(
      {required this.item, required this.lang, required this.accent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _DishDetail(item: item)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _image(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.tituloFor(lang),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtituloFor(lang),
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image() {
    final path = item.imagenAssetPath;
    final fallback = ColoredBox(color: accent.withValues(alpha: 0.4));
    if (path == null) return fallback;
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

/// Detalle del plato: imagen + cuerpo, todo proveniente de la misma fila de
/// Supabase ya cargada (no hace falta re-fetch). Reacciona al idioma.
class _DishDetail extends StatelessWidget {
  final EditorialContent item;
  const _DishDetail({required this.item});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final path = item.imagenAssetPath;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppColors.marronProfundo,
            foregroundColor: AppColors.cremaPergamino,
            flexibleSpace: FlexibleSpaceBar(
              background: path == null
                  ? const ColoredBox(color: AppColors.marronProfundo)
                  : Image.asset(
                      path,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const ColoredBox(color: AppColors.marronProfundo),
                    ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  item.tituloFor(lang),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cremaPergamino,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtituloFor(lang),
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: AppColors.cremaPergamino.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  item.contenidoFor(lang),
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    height: 1.7,
                    color: AppColors.cremaPergamino.withValues(alpha: 0.9),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
