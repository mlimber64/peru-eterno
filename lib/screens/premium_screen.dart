import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import '../data/eras_repository.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final premiumProvider = context.watch<PremiumProvider>();

    if (premiumProvider.isPremium) {
      return _buildAlreadyUnlocked(context, t);
    }

    return Scaffold(
      backgroundColor: AppColors.marronOscuro,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.cremaPergamino,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  _buildIcon()
                      .animate()
                      .scale(
                        duration: 700.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 28),
                  // Title
                  Text(
                    t('premium.title'),
                    style: AppTextStyles.eraTitleLarge.copyWith(
                      color: AppColors.cremaPergamino,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                  const SizedBox(height: 10),
                  Text(
                    t('premium.description'),
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: AppColors.cremaPergamino.withOpacity(0.7),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
                  const SizedBox(height: 32),
                  // Price card
                  _buildPriceCard(context, t, premiumProvider)
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 400.ms)
                      .slideY(begin: 0.2, end: 0, delay: 400.ms),
                  const SizedBox(height: 28),
                  // Features
                  _buildFeaturesList(context, t)
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 500.ms),
                  const SizedBox(height: 32),
                  // Premium eras preview
                  _buildPremiumErasPreview(t)
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 600.ms),
                  const SizedBox(height: 32),
                  // Restore purchase
                  TextButton(
                    onPressed: () async {
                      await premiumProvider.restorePurchase();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(
                      t('premium.restore_button'),
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: AppColors.cremaPergamino.withOpacity(0.5),
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.cremaPergamino.withOpacity(0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.ocre, Color(0xFFE8A020)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ocre.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 42,
      ),
    );
  }

  Widget _buildPriceCard(BuildContext context, String Function(String) t,
      PremiumProvider premiumProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.ocre.withOpacity(0.2),
            AppColors.terracota.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.ocre.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            t('premium.price'),
            style: AppTextStyles.premiumPrice,
          ),
          const SizedBox(height: 4),
          Text(
            t('premium.subtitle'),
            style: GoogleFonts.lato(
              fontSize: 13,
              color: AppColors.cremaPergamino.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await premiumProvider.unlockPremium();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ocre,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                t('premium.unlock_button').toUpperCase(),
                style: GoogleFonts.lato(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(
      BuildContext context, String Function(String) t) {
    final features = context.read<LanguageProvider>().tList('premium.features');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('premium.features_title'),
          style: GoogleFonts.playfairDisplay(
            fontSize: 16,
            color: AppColors.cremaPergamino,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...features.map(
          (feature) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.ocre.withOpacity(0.2),
                    border: Border.all(color: AppColors.ocre, width: 1),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 11,
                    color: AppColors.ocre,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: AppColors.cremaPergamino.withOpacity(0.85),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumErasPreview(String Function(String) t) {
    final premiumEras =
        ErasRepository.allEras.where((e) => e.isPremium).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 1,
          color: AppColors.ocre.withOpacity(0.2),
        ),
        const SizedBox(height: 20),
        ...premiumEras.map(
          (era) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: era.accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  t('eras.${era.id}.title'),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    color: AppColors.cremaPergamino,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  t('eras.${era.id}.period'),
                  style: GoogleFonts.lato(
                    fontSize: 11,
                    color: AppColors.cremaPergamino.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlreadyUnlocked(
      BuildContext context, String Function(String) t) {
    return Scaffold(
      backgroundColor: AppColors.marronOscuro,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.verified_rounded,
                color: AppColors.ocre,
                size: 80,
              ),
              const SizedBox(height: 24),
              Text(
                'Premium',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 32,
                  color: AppColors.ocre,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Hai accesso completo a tutta la storia del Perù!',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  color: AppColors.cremaPergamino,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ocre,
                  foregroundColor: Colors.white,
                ),
                child: Text(t('navigation.back')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
