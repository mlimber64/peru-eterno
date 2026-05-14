import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../models/wikipedia_content.dart';

class WikipediaSectionWidget extends StatefulWidget {
  final WikipediaContent? content;
  final bool isLoading;
  final Color accentColor;
  final String languageCode;
  final String? fallbackDescription;

  const WikipediaSectionWidget({
    super.key,
    required this.content,
    required this.isLoading,
    required this.accentColor,
    required this.languageCode,
    this.fallbackDescription,
  });

  @override
  State<WikipediaSectionWidget> createState() => _WikipediaSectionWidgetState();
}

class _WikipediaSectionWidgetState extends State<WikipediaSectionWidget> {
  static const int _maxSections = 5;
  static const int _previewChars = 600;

  final Map<int, bool> _expanded = {};

  @override
  void didUpdateWidget(WikipediaSectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.languageCode != widget.languageCode) {
      setState(() => _expanded.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return _buildLoader();

    final content = widget.content;
    final fallback = widget.fallbackDescription;

    if (content != null && content.hasContent) {
      final isWrongLanguage = content.displayLang.isNotEmpty &&
          content.displayLang != widget.languageCode;

      if (!isWrongLanguage) return _buildArticle(content);

      // Wrong language — prefer static description in user's language
      if (fallback != null && fallback.isNotEmpty) {
        return _buildFallback(fallback);
      }
      // Show cross-language Wikipedia as last resort
      return _buildArticle(content);
    }

    if (fallback != null && fallback.isNotEmpty) {
      return _buildFallback(fallback);
    }
    return const SizedBox.shrink();
  }

  // ── Loader ────────────────────────────────────────────────────────────────

  Widget _buildLoader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _loadingLabel,
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

  // ── Fallback ──────────────────────────────────────────────────────────────

  Widget _buildFallback(String description) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: GoogleFonts.lato(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.75,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _editorialSourceLabel,
            style: GoogleFonts.lato(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ── Full article ──────────────────────────────────────────────────────────

  Widget _buildArticle(WikipediaContent content) {
    final visibleSections =
        content.contentSections.take(_maxSections).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),

        _buildWikiBadge(content.displayLang),
        const SizedBox(height: 20),

        if (content.hasThumbnail) ...[
          _buildThumbnail(content.thumbnailUrl!),
          const SizedBox(height: 20),
        ],

        if (content.leadSection != null)
          _buildLeadText(content.leadSection!.content),

        ...visibleSections.asMap().entries.map(
              (entry) => _buildSection(entry.value, entry.key),
            ),

        const SizedBox(height: 28),
        _buildReadMoreButton(content.sourceUrl),
        const SizedBox(height: 16),
        _buildAttribution(content),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildWikiBadge(String displayLang) {
    final effectiveLang =
        displayLang.isNotEmpty ? displayLang : widget.languageCode;
    return Row(
      children: [
        Container(width: 32, height: 2, color: widget.accentColor),
        const SizedBox(width: 12),
        Text(
          'WIKIPEDIA',
          style: GoogleFonts.lato(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: widget.accentColor,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: widget.accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.accentColor.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Text(
            effectiveLang.toUpperCase(),
            style: GoogleFonts.lato(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: widget.accentColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: widget.accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.accentColor.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Text(
            'CC BY-SA',
            style: GoogleFonts.lato(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: widget.accentColor.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: 210,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          height: 210,
          decoration: BoxDecoration(
            color: widget.accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.accentColor,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildLeadText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.lato(
          fontSize: 15,
          color: AppColors.textPrimary,
          height: 1.75,
        ),
      ),
    );
  }

  Widget _buildSection(WikipediaSection section, int index) {
    final isExpanded = _expanded[index] ?? false;
    final isSubSection = section.level > 1;
    final isTruncated = section.content.length > _previewChars;
    final preview = isTruncated
        ? '${section.content.substring(0, _previewChars).trimRight()}…'
        : section.content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        InkWell(
          onTap: () => setState(() => _expanded[index] = !isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: isSubSection ? 3 : 4,
                  height: isSubSection ? 16 : 20,
                  decoration: BoxDecoration(
                    color: isSubSection
                        ? widget.accentColor.withOpacity(0.5)
                        : widget.accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(width: isSubSection ? 10 : 12),
                Expanded(
                  child: Text(
                    section.title,
                    style: isSubSection
                        ? GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          )
                        : GoogleFonts.playfairDisplay(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: widget.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),

        Container(
          height: 1,
          color: isSubSection
              ? AppColors.dividerColor.withOpacity(0.5)
              : AppColors.dividerColor,
          margin: const EdgeInsets.only(top: 4),
        ),

        Padding(
          padding: const EdgeInsets.only(top: 14, left: 4),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Text(
              section.content,
              style: GoogleFonts.lato(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.75,
              ),
            ),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview,
                  style: GoogleFonts.lato(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.75,
                  ),
                ),
                if (isTruncated) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => setState(() => _expanded[index] = true),
                    child: Text(
                      _expandLabel,
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: widget.accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadMoreButton(String url) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _launchUrl(url),
        icon: Icon(Icons.open_in_new_rounded,
            size: 16, color: widget.accentColor),
        label: Text(
          _readMoreLabel,
          style: GoogleFonts.lato(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: widget.accentColor,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: widget.accentColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildAttribution(WikipediaContent content) {
    final isFallback = content.displayLang.isNotEmpty &&
        content.displayLang != widget.languageCode;
    final langLabel = (content.displayLang.isNotEmpty
            ? content.displayLang
            : widget.languageCode)
        .toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dividerColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 13, color: AppColors.textSecondary),
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
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (isFallback) ...[
            const SizedBox(height: 4),
            Text(
              _fallbackNoteLabel(langLabel),
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Localized labels ──────────────────────────────────────────────────────

  String get _loadingLabel {
    switch (widget.languageCode) {
      case 'en':
        return 'Loading from Wikipedia…';
      case 'es':
        return 'Cargando desde Wikipedia…';
      default:
        return 'Caricamento da Wikipedia…';
    }
  }

  String get _readMoreLabel {
    switch (widget.languageCode) {
      case 'en':
        return 'Read more on Wikipedia';
      case 'es':
        return 'Leer más en Wikipedia';
      default:
        return 'Leggi di più su Wikipedia';
    }
  }

  String get _expandLabel {
    switch (widget.languageCode) {
      case 'en':
        return 'Show more ↓';
      case 'es':
        return 'Mostrar más ↓';
      default:
        return 'Mostra di più ↓';
    }
  }

  String get _editorialSourceLabel {
    switch (widget.languageCode) {
      case 'en':
        return 'Source: editorial content';
      case 'es':
        return 'Fuente: contenido editorial';
      default:
        return 'Fonte: contenuto editoriale';
    }
  }

  String _fallbackNoteLabel(String lang) {
    switch (widget.languageCode) {
      case 'en':
        return 'Content available in: $lang';
      case 'es':
        return 'Contenido disponible en: $lang';
      default:
        return 'Contenuto disponibile in: $lang';
    }
  }
}
