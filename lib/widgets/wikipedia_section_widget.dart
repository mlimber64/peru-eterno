import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  // When true, the lead (summary) section is hidden — shown in the Resumen tab.
  final bool hideLeadSection;
  // Set true when the network fetch failed AND there is no cached content.
  final bool hasFailed;
  final VoidCallback? onRetry;

  const WikipediaSectionWidget({
    super.key,
    required this.content,
    required this.isLoading,
    required this.accentColor,
    required this.languageCode,
    this.fallbackDescription,
    this.hideLeadSection = false,
    this.hasFailed = false,
    this.onRetry,
  });

  @override
  State<WikipediaSectionWidget> createState() => _WikipediaSectionWidgetState();
}

class _WikipediaSectionWidgetState extends State<WikipediaSectionWidget> {
  static const int _previewChars = 800;

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
    if (widget.isLoading) return _buildSkeleton();
    if (widget.hasFailed) return _buildRetryView();

    final content = widget.content;
    final fallback = widget.fallbackDescription;

    if (content != null && content.hasContent) {
      final isWrongLanguage = content.displayLang.isNotEmpty &&
          content.displayLang != widget.languageCode;

      if (!isWrongLanguage) return _buildArticle(content);
      if (fallback != null && fallback.isNotEmpty) return _buildFallback(fallback);
      return _buildArticle(content);
    }

    if (fallback != null && fallback.isNotEmpty) return _buildFallback(fallback);
    return const SizedBox.shrink();
  }

  // ── Skeleton loader ───────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBar(width: 200, height: 12),
          const SizedBox(height: 20),
          _skeletonBar(width: double.infinity, height: 14, delay: 0),
          const SizedBox(height: 8),
          _skeletonBar(width: double.infinity, height: 14, delay: 60),
          const SizedBox(height: 8),
          _skeletonBar(width: 260, height: 14, delay: 120),
          const SizedBox(height: 28),
          _skeletonBar(width: 160, height: 12, delay: 180),
          const SizedBox(height: 16),
          _skeletonBar(width: double.infinity, height: 14, delay: 240),
          const SizedBox(height: 8),
          _skeletonBar(width: double.infinity, height: 14, delay: 300),
          const SizedBox(height: 8),
          _skeletonBar(width: 200, height: 14, delay: 360),
          const SizedBox(height: 28),
          _skeletonBar(width: 180, height: 12, delay: 420),
          const SizedBox(height: 16),
          _skeletonBar(width: double.infinity, height: 14, delay: 480),
          const SizedBox(height: 8),
          _skeletonBar(width: 300, height: 14, delay: 540),
        ],
      ),
    );
  }

  Widget _skeletonBar({
    required double width,
    required double height,
    int delay = 0,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.dividerColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(
          begin: 0.35,
          end: 0.9,
          duration: 900.ms,
          delay: Duration(milliseconds: delay),
          curve: Curves.easeInOut,
        );
  }

  // ── Retry view ────────────────────────────────────────────────────────────

  Widget _buildRetryView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 44,
            color: AppColors.textSecondary.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            _noConnectionLabel,
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: widget.onRetry,
            icon: Icon(Icons.refresh_rounded, size: 16, color: widget.accentColor),
            label: Text(
              _retryLabel,
              style: GoogleFonts.lato(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: widget.accentColor,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              side: BorderSide(color: widget.accentColor, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Fallback (no Wikipedia article) ──────────────────────────────────────

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
    final sections = widget.hideLeadSection
        ? content.contentSections
        : [if (content.leadSection != null) content.leadSection!, ...content.contentSections];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        _buildWikiBadge(content),
        const SizedBox(height: 4),

        if (content.isFromCache) ...[
          const SizedBox(height: 10),
          _buildOfflineBadge(),
        ],

        const SizedBox(height: 16),

        if (!widget.hideLeadSection && content.hasThumbnail) ...[
          _buildThumbnail(content.thumbnailUrl!),
          const SizedBox(height: 20),
        ],

        ...sections.asMap().entries.map(
              (e) => e.value.isLead
                  ? _buildLeadText(e.value.content)
                  : _buildSection(e.value, e.key),
            ),

        const SizedBox(height: 24),
        _buildReadMoreButton(content.sourceUrl),
        const SizedBox(height: 12),
        _buildAttribution(content),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildWikiBadge(WikipediaContent content) {
    final effectiveLang = content.displayLang.isNotEmpty
        ? content.displayLang
        : widget.languageCode;

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
        _chip(effectiveLang.toUpperCase()),
        const SizedBox(width: 6),
        _chip('CC BY-SA', opacity: 0.6),
      ],
    );
  }

  Widget _chip(String label, {double opacity = 1.0}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.accentColor.withOpacity(0.10 * opacity + 0.02),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: widget.accentColor.withOpacity(0.3 * opacity),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.lato(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: widget.accentColor.withOpacity(opacity),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildOfflineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 12, color: Colors.orange),
          const SizedBox(width: 6),
          Text(
            _offlineCacheLabel,
            style: GoogleFonts.lato(
              fontSize: 11,
              color: Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
    final isTruncated = section.content.length >= _previewChars;
    final preview = isTruncated
        ? '${section.content.substring(0, _previewChars).trimRight()}…'
        : section.content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // Section header — tap to expand/collapse
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
                    section.title.isEmpty ? _sectionLabel(index) : section.title,
                    style: isSubSection
                        ? GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          )
                        : GoogleFonts.playfairDisplay(
                            fontSize: 18,
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
          padding: const EdgeInsets.only(top: 12, left: 4),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 280),
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
        icon: Icon(Icons.open_in_new_rounded, size: 16, color: widget.accentColor),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${switch (widget.languageCode) { 'en' => 'Source', 'es' => 'Fuente', _ => 'Fonte' }}: Wikipedia $langLabel — ',
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
            const SizedBox(height: 3),
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

  String _sectionLabel(int index) {
    switch (widget.languageCode) {
      case 'en':
        return 'Section ${index + 1}';
      case 'es':
        return 'Sección ${index + 1}';
      default:
        return 'Sezione ${index + 1}';
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

  String get _noConnectionLabel {
    switch (widget.languageCode) {
      case 'en':
        return 'No connection. Check your internet\nand try again.';
      case 'es':
        return 'Sin conexión. Verifica tu internet\ne intenta de nuevo.';
      default:
        return 'Nessuna connessione. Verifica internet\ne riprova.';
    }
  }

  String get _retryLabel {
    switch (widget.languageCode) {
      case 'en':
        return 'Retry';
      case 'es':
        return 'Reintentar';
      default:
        return 'Riprova';
    }
  }

  String get _offlineCacheLabel {
    switch (widget.languageCode) {
      case 'en':
        return 'Showing cached content';
      case 'es':
        return 'Mostrando contenido sin conexión';
      default:
        return 'Contenuto dalla cache locale';
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
