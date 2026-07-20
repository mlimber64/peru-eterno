import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

/// Renderiza un párrafo del contenido editorial de Historia soportando el
/// markdown ligero que traen los datos enriquecidos
/// (assets/data-refactor/peru-prehispanico/):
///
///   • `**[¿SABÍAS QUÉ?]**`, `**[CURIOSITÀ]**`, `**[FUN FACT]**` → callout
///     destacado con el bloque de curiosidad.
///   • `**negrita**`  → texto en negrita con color de acento.
///   • `*cursiva*`    → texto en cursiva (usado en la línea de créditos).
///
/// Detecta automáticamente el tipo de párrafo y elige la presentación.
class HistoriaParagraph extends StatelessWidget {
  final String text;
  final Color accent;
  final double textScale;

  const HistoriaParagraph({
    super.key,
    required this.text,
    required this.accent,
    this.textScale = 1.0,
  });

  /// ¿El párrafo es un bloque de curiosidad "¿Sabías qué?" / "Curiosità" / …?
  static bool isCallout(String paragraph) =>
      paragraph.trimLeft().startsWith('**[');

  /// Quita el markdown ligero (`**`, `*`, `[]`) para usar el texto en
  /// previsualizaciones planas (tarjetas de lista).
  static String stripMarkdown(String text) => text
      .replaceAll('**', '')
      .replaceAll('*', '')
      .replaceAll('[', '')
      .replaceAll(']', '')
      .trim();

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();

    if (isCallout(trimmed)) {
      return _CalloutBlock(
        raw: trimmed,
        accent: accent,
        textScale: textScale,
      );
    }

    final baseStyle = GoogleFonts.lato(
      fontSize: 16 * textScale,
      color: AppColors.cremaPergamino.withOpacity(0.85),
      height: 1.8,
    );

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: buildInlineSpans(trimmed, baseStyle, accent),
      ),
    );
  }

  /// Convierte `**negrita**` y `*cursiva*` de un texto en una lista de spans.
  static List<TextSpan> buildInlineSpans(
    String text,
    TextStyle baseStyle,
    Color accent,
  ) {
    final spans = <TextSpan>[];
    // Captura **negrita** (grupo 1) o *cursiva* (grupo 2).
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*', dotAll: true);
    int last = 0;

    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(TextSpan(
          text: m.group(1),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: m.group(2),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      }
      last = m.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return spans;
  }
}

/// Bloque destacado para las curiosidades "¿Sabías qué?".
class _CalloutBlock extends StatelessWidget {
  final String raw;
  final Color accent;
  final double textScale;

  const _CalloutBlock({
    required this.raw,
    required this.accent,
    required this.textScale,
  });

  @override
  Widget build(BuildContext context) {
    // Separa el encabezado `**[...]**` del cuerpo.
    final headerMatch = RegExp(r'^\*\*\[(.+?)\]\*\*', dotAll: true).firstMatch(raw);
    final header = headerMatch?.group(1)?.trim() ?? '';
    final body = headerMatch != null
        ? raw.substring(headerMatch.end).trim()
        : raw.trim();

    final bodyStyle = GoogleFonts.lato(
      fontSize: 15 * textScale,
      color: AppColors.cremaPergamino.withOpacity(0.88),
      height: 1.7,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 16, color: accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  header,
                  style: GoogleFonts.lato(
                    fontSize: 11 * textScale,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: bodyStyle,
              children: HistoriaParagraph.buildInlineSpans(body, bodyStyle, accent),
            ),
          ),
        ],
      ),
    );
  }
}
