import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../models/historia_article.dart';
import 'historia_rich_text.dart';

/// Tarjeta destacada "¿Sabías qué?" / "Curiosità" / "Fun fact".
///
/// Diseño con identidad propia (borde e ícono dorados) para diferenciarla
/// claramente del resto del texto, sin depender del color de acento de la
/// etapa. Reusable en cualquier pantalla que muestre un [ArticleCallout].
class DidYouKnowCard extends StatelessWidget {
  final ArticleCallout callout;
  final double textScale;

  const DidYouKnowCard({
    super.key,
    required this.callout,
    this.textScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    const gold = AppColors.ocre;
    final bodyStyle = GoogleFonts.lato(
      fontSize: 15 * textScale,
      color: AppColors.cremaPergamino.withValues(alpha: 0.9),
      height: 1.7,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 14, color: gold),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  callout.header,
                  style: GoogleFonts.lato(
                    fontSize: 11.5 * textScale,
                    fontWeight: FontWeight.w800,
                    color: gold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: bodyStyle,
              children:
                  HistoriaParagraph.buildInlineSpans(callout.body, bodyStyle, gold),
            ),
          ),
        ],
      ),
    );
  }
}
