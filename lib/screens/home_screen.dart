import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import '../data/eras_repository.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/era_timeline_card.dart';
import '../widgets/language_selector_button.dart';
import 'premium_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final isPremium = context.watch<PremiumProvider>().isPremium;
    final eras = ErasRepository.allEras;

    return Scaffold(
      backgroundColor: AppColors.bgColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, t, isPremium),
          SliverToBoxAdapter(
            child: _buildHeroHeader(context, t),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final era = eras[index];
                  return EraTimelineCard(
                    era: era,
                    isFirst: index == 0,
                    isLast: index == eras.length - 1,
                    index: index,
                  );
                },
                childCount: eras.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(
      BuildContext context, String Function(String) t, bool isPremium) {
    return SliverAppBar(
      backgroundColor: AppColors.marronOscuro,
      foregroundColor: AppColors.cremaPergamino,
      pinned: true,
      elevation: 0,
      expandedHeight: 0,
      title: Text(
        t('app.name').toUpperCase(),
        style: AppTextStyles.appBarTitle,
      ),
      actions: [
        const LanguageSelectorButton(),
        if (!isPremium)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                );
              },
              child: Text(
                'PREMIUM',
                style: GoogleFonts.lato(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ocre,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroHeader(BuildContext context, String Function(String) t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.marronOscuro,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.marronOscuro.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('home.subtitle'),
            style: GoogleFonts.lato(
              fontSize: 13,
              color: AppColors.ocre,
              letterSpacing: 3,
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 100.ms),
          const SizedBox(height: 8),
          Text(
            '3000 a.C. → 1821 d.C.',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              color: AppColors.cremaPergamino,
              fontWeight: FontWeight.w300,
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
          const SizedBox(height: 16),
          _buildEraCountBadges(t),
        ],
      ),
    );
  }

  Widget _buildEraCountBadges(String Function(String) t) {
    return Row(
      children: [
        _badge(t('premium.free_label'), '3', AppColors.verdeAndino),
        const SizedBox(width: 10),
        _badge(t('premium.premium_label'), '4', AppColors.ocre),
      ],
    ).animate().fadeIn(duration: 600.ms, delay: 350.ms);
  }

  Widget _badge(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
