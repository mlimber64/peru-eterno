import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/navigation/app_navigation.dart';
import '../models/era_model.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import 'image_with_fallback.dart';
import 'premium_lock_overlay.dart';

class EraTimelineCard extends StatelessWidget {
  final EraModel era;
  final bool isFirst;
  final bool isLast;
  final int index;

  const EraTimelineCard({
    super.key,
    required this.era,
    this.isFirst = false,
    this.isLast = false,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final isPremiumUnlocked = context.watch<PremiumProvider>().isPremium;
    final isLocked = era.isPremium && !isPremiumUnlocked;

    return Animate(
      effects: [
        FadeEffect(
          duration: 500.ms,
          delay: (index * 120).ms,
        ),
        SlideEffect(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
          duration: 500.ms,
          delay: (index * 120).ms,
          curve: Curves.easeOutCubic,
        ),
      ],
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline left column
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  if (!isFirst)
                    Flexible(
                      child: Container(
                        width: 2,
                        color: AppColors.dividerColor,
                      ),
                    ),
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: era.accentColor,
                      border: Border.all(
                        color: AppColors.cremaPergamino,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: era.accentColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Flexible(
                      child: Container(
                        width: 2,
                        color: AppColors.dividerColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: isLocked
                    ? PremiumLockOverlay(child: _buildCardContent(context, t))
                    : GestureDetector(
                        onTap: () => AppNavigation.openEra(context, era),
                        child: _buildCardContent(context, t),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, String Function(String) t) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: era.accentColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 130,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImageWithFallback(
                    assetPath: era.imageAssetPath(era.imageFilenames.first),
                    fallbackColor: era.accentColor,
                    fit: BoxFit.cover,
                  ),
                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          era.accentColor.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  // Period badge
                  Positioned(
                    bottom: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.ocre.withValues(alpha: 0.6),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        t('eras.${era.id}.period'),
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          color: AppColors.cremaPergamino,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('eras.${era.id}.title'),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t('eras.${era.id}.subtitle'),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  t('eras.${era.id}.description_short'),
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.55,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Highlight badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: era.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: era.accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        t('eras.${era.id}.highlight'),
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: era.accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    // Discover button
                    Row(
                      children: [
                        Text(
                          t('navigation.discover'),
                          style: GoogleFonts.lato(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: era.accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: era.accentColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
