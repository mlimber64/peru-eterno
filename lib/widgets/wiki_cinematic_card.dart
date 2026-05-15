import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/category_config.dart';
import '../models/content_item.dart';
import '../providers/language_provider.dart';
import '../services/wikipedia_service.dart';
import 'cinematic_card.dart';

/// A CinematicCard that lazily fetches its thumbnail from Wikipedia.
/// Shows the gradient placeholder immediately, then crossfades to the image.
class WikiCinematicCard extends StatefulWidget {
  final ContentItem item;
  final String? title;
  final String? subtitle;
  final String? badge;
  final bool isPremium;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const WikiCinematicCard({
    super.key,
    required this.item,
    this.title,
    this.subtitle,
    this.badge,
    this.isPremium = false,
    this.onTap,
    this.width = double.infinity,
    this.height = 200,
  });

  @override
  State<WikiCinematicCard> createState() => _WikiCinematicCardState();
}

class _WikiCinematicCardState extends State<WikiCinematicCard> {
  String? _thumbnailUrl;
  String? _loadedForLang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = context.read<LanguageProvider>().currentLanguage;
    if (lang != _loadedForLang) {
      _loadedForLang = lang;
      _loadThumbnail(lang);
    }
  }

  Future<void> _loadThumbnail(String lang) async {
    final url = await WikipediaService.instance.fetchThumbnailOnly(
      contentId: widget.item.id,
      lang: lang,
      slugMap: widget.item.wikipediaSlug,
    );
    if (mounted && url != _thumbnailUrl) {
      setState(() => _thumbnailUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;

    return CinematicCard(
      networkImageUrl: _thumbnailUrl,
      accentColor: CategoryConfigs.colorOf(widget.item.category),
      title: widget.title ?? widget.item.localizedTitle(t),
      subtitle: widget.subtitle ?? widget.item.localizedSubtitle(t),
      badge: widget.badge,
      isPremium: widget.isPremium,
      onTap: widget.onTap,
      width: widget.width,
      height: widget.height,
    );
  }
}
