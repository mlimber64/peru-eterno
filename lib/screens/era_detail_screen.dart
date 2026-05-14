import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/era_model.dart';
import '../providers/language_provider.dart';
import '../widgets/image_with_fallback.dart';
import '../widgets/language_selector_button.dart';
import 'gallery_screen.dart';

class EraDetailScreen extends StatelessWidget {
  final EraModel era;

  const EraDetailScreen({super.key, required this.era});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;

    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, t),
          SliverToBoxAdapter(
            child: _buildContent(context, t),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(
      BuildContext context, String Function(String) t) {
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
      actions: [const LanguageSelectorButton()],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Stack(
          fit: StackFit.expand,
          children: [
            ImageWithFallback(
              assetPath: era.imageAssetPath(era.imageFilenames.first),
              fallbackColor: era.accentColor,
              fit: BoxFit.cover,
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: era.accentColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t('eras.${era.id}.period'),
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
                    t('eras.${era.id}.title'),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    t('eras.${era.id}.subtitle'),
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

  Widget _buildContent(BuildContext context, String Function(String) t) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          Text(
            t('eras.${era.id}.description'),
            style: GoogleFonts.lato(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.75,
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
          const SizedBox(height: 28),
          // Divider
          Row(
            children: [
              Container(width: 32, height: 2, color: era.accentColor),
              const SizedBox(width: 12),
              Text(
                t('navigation.gallery').toUpperCase(),
                style: GoogleFonts.lato(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: era.accentColor,
                  letterSpacing: 2,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
          const SizedBox(height: 16),
          // Gallery preview
          _buildGalleryPreview(context, t)
              .animate()
              .fadeIn(duration: 600.ms, delay: 400.ms),
          const SizedBox(height: 24),
          // View full gallery button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openGallery(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: era.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_library_rounded, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    t('navigation.gallery').toUpperCase(),
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGalleryPreview(
      BuildContext context, String Function(String) t) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: era.imageFilenames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _openGallery(context, initialIndex: index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 110,
                child: ImageWithFallback(
                  assetPath:
                      era.imageAssetPath(era.imageFilenames[index]),
                  fallbackColor: era.accentColor.withOpacity(0.7),
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
              ),
            ),
          );
        },
      ),
    );
  }

  void _openGallery(BuildContext context, {int initialIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GalleryScreen(
          era: era,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}
