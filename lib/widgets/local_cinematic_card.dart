import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants/category_config.dart';
import '../data/editorial_repository.dart';
import '../models/content_ref.dart';
import '../providers/language_provider.dart';
import 'cinematic_card.dart';

/// CinematicCard respaldada por assets locales del EditorialRepository.
/// Muestra el gradiente de categoría de inmediato; si existe imagen local
/// en el JSON editorial, cambia a ella una vez resuelto (usualmente < 1 frame
/// tras la primera carga, dado el cache en memoria del repositorio).
///
/// Acepta cualquier [ContentRef] (en la práctica, siempre un ContentItem no
/// era: las eras se renderizan con CinematicCard directamente).
class LocalCinematicCard extends StatefulWidget {
  final ContentRef item;
  final String? title;
  final String? subtitle;
  final String? badge;
  final bool isPremium;
  final bool isComingSoon;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const LocalCinematicCard({
    super.key,
    required this.item,
    this.title,
    this.subtitle,
    this.badge,
    this.isPremium = false,
    this.isComingSoon = false,
    this.onTap,
    this.width = double.infinity,
    this.height = 200,
  });

  @override
  State<LocalCinematicCard> createState() => _LocalCinematicCardState();
}

class _LocalCinematicCardState extends State<LocalCinematicCard> {
  String? _assetPath;

  @override
  void initState() {
    super.initState();
    _resolveAsset();
  }

  @override
  void didUpdateWidget(LocalCinematicCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El GridView reutiliza los State al cambiar de filtro: si el item cambió,
    // hay que reiniciar la imagen y volver a resolverla para el nuevo contenido.
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.category != widget.item.category) {
      _assetPath = null;
      _resolveAsset();
    }
  }

  Future<void> _resolveAsset() async {
    final content = await EditorialRepository.findById(
        widget.item.id, widget.item.category);
    final path = content?.imagenAssetPath;
    if (path == null || !mounted) return;

    // Confirma que el archivo existe en el bundle antes de asignarlo.
    // Si no existe aún, el gradiente de categoría sigue visible sin parpadeo.
    try {
      await rootBundle.load(path);
      if (mounted) setState(() => _assetPath = path);
    } catch (_) {
      // Asset no disponible — el gradiente de fallback permanece activo.
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    return CinematicCard(
      assetImagePath: _assetPath,
      accentColor: CategoryConfigs.colorOf(widget.item.category),
      title: widget.title ?? widget.item.localizedTitle(t),
      subtitle: widget.subtitle ?? widget.item.localizedSubtitle(t),
      badge: widget.badge,
      isPremium: widget.isPremium,
      isComingSoon: widget.isComingSoon,
      onTap: widget.onTap,
      width: widget.width,
      height: widget.height,
    );
  }
}
