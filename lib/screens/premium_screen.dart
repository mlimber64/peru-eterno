import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import '../models/legal_document.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import 'legal_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  PremiumPlan _selectedPlan = PremiumPlan.weekly;

  static const _benefitIcons = [
    Icons.headphones_rounded,
    Icons.auto_stories_rounded,
    Icons.style_rounded,
    Icons.cloud_off_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;
    final premium = context.watch<PremiumProvider>();

    // ── Mensajes de compra localizados ──────────────────────────────────────
    final messageKey = premium.lastError;
    if (messageKey != null) {
      final isError = premium.messageIsError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        premium.consumeMessage();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(t(messageKey)),
              backgroundColor:
                  isError ? AppColors.terracota : AppColors.verdeAndino,
              behavior: SnackBarBehavior.floating,
            ),
          );
      });
    }

    if (premium.isPremium) {
      return _buildAlreadyUnlocked(context, t, premium);
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
                  _buildIcon()
                      .animate()
                      .scale(duration: 700.ms, curve: Curves.elasticOut)
                      .fadeIn(duration: 400.ms),
                  const SizedBox(height: 24),
                  Text(
                    t('premium.hero_title'),
                    style: AppTextStyles.eraTitleLarge.copyWith(
                      color: AppColors.cremaPergamino,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                  const SizedBox(height: 10),
                  Text(
                    t('premium.hero_subtitle'),
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: AppColors.cremaPergamino.withOpacity(0.7),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
                  const SizedBox(height: 28),
                  _buildFeaturesList(context, t)
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 400.ms),
                  const SizedBox(height: 24),
                  if (!premium.hasUsedTrial)
                    _buildTrialBanner(t)
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 450.ms)
                        .slideY(begin: 0.15, end: 0, delay: 450.ms),
                  if (!premium.hasUsedTrial) const SizedBox(height: 20),
                  _buildPlanCards(context, t, premium)
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 500.ms)
                      .slideY(begin: 0.15, end: 0, delay: 500.ms),
                  const SizedBox(height: 22),
                  _buildCta(context, t, premium)
                      .animate()
                      .fadeIn(duration: 600.ms, delay: 600.ms),
                  const SizedBox(height: 22),
                  _buildLegalFooter(context, t, premium),
                  const SizedBox(height: 32),
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

  // ── Beneficios ───────────────────────────────────────────────────────────

  Widget _buildFeaturesList(BuildContext context, String Function(String) t) {
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
        const SizedBox(height: 14),
        ...List.generate(features.length, (i) {
          final icon = i < _benefitIcons.length
              ? _benefitIcons[i]
              : Icons.check_circle_rounded;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.ocre.withOpacity(0.16),
                    border: Border.all(color: AppColors.ocre.withOpacity(0.4)),
                  ),
                  child: Icon(icon, size: 16, color: AppColors.ocre),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      features[i],
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: AppColors.cremaPergamino.withOpacity(0.85),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── Banner de prueba gratuita ───────────────────────────────────────────

  Widget _buildTrialBanner(String Function(String) t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.verdeAndino.withOpacity(0.25),
            AppColors.verdeAndino.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.verdeAndino.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration_rounded,
              color: AppColors.verdeAndino, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t('premium.trial_banner'),
              style: GoogleFonts.lato(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.cremaPergamino,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tarjetas de plan ───────────────────────────────────────────────────

  Widget _buildPlanCards(
      BuildContext context, String Function(String) t, PremiumProvider p) {
    return Row(
      children: [
        Expanded(
          child: _PlanCard(
            label: t('premium.plan_weekly_label'),
            price: p.localizedPriceFor(PremiumPlan.weekly) ??
                t('premium.plan_weekly_price'),
            badge: t('premium.plan_weekly_badge'),
            badgeColor: AppColors.ocre,
            isSelected: _selectedPlan == PremiumPlan.weekly,
            onTap: () => setState(() => _selectedPlan = PremiumPlan.weekly),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlanCard(
            label: t('premium.plan_annual_label'),
            price: p.localizedPriceFor(PremiumPlan.annual) ??
                t('premium.plan_annual_price'),
            badge: t('premium.plan_annual_badge'),
            badgeColor: AppColors.verdeAndino,
            isSelected: _selectedPlan == PremiumPlan.annual,
            onTap: () => setState(() => _selectedPlan = PremiumPlan.annual),
          ),
        ),
      ],
    );
  }

  // ── CTA ──────────────────────────────────────────────────────────────────

  Widget _buildCta(
      BuildContext context, String Function(String) t, PremiumProvider p) {
    final showTrialCta = !p.hasUsedTrial;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: p.isPurchasePending
            ? null
            : () async {
                if (showTrialCta) {
                  await p.startFreeTrial();
                } else {
                  await p.buyPlan(_selectedPlan);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ocre,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.ocre.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: p.isPurchasePending
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                (showTrialCta
                        ? t('premium.cta_trial')
                        : t('premium.cta_subscribe'))
                    .toUpperCase(),
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }

  // ── Pie legal ────────────────────────────────────────────────────────────

  Widget _buildLegalFooter(
      BuildContext context, String Function(String) t, PremiumProvider p) {
    void openLegal(LegalDocType type) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LegalScreen(type: type)),
      );
    }

    TextStyle style() => GoogleFonts.lato(
          fontSize: 11,
          color: AppColors.cremaPergamino.withOpacity(0.45),
          decoration: TextDecoration.underline,
          decorationColor: AppColors.cremaPergamino.withOpacity(0.3),
        );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      children: [
        TextButton(
          onPressed: () => openLegal(LegalDocType.terms),
          child: Text(t('premium.legal_terms'), style: style()),
        ),
        Text('·', style: style()),
        TextButton(
          onPressed: () => openLegal(LegalDocType.privacy),
          child: Text(t('premium.legal_privacy'), style: style()),
        ),
        Text('·', style: style()),
        TextButton(
          onPressed: () async => p.restorePurchases(),
          child: Text(t('premium.restore_button'), style: style()),
        ),
      ],
    );
  }

  // ── Ya premium ───────────────────────────────────────────────────────────

  Widget _buildAlreadyUnlocked(
      BuildContext context, String Function(String) t, PremiumProvider p) {
    final subtitle = p.isInTrial
        ? '${t('premium.trial_active_prefix')} ${p.daysLeftInTrial} ${t('premium.trial_active_suffix')}'
        : t('premium.active_message');

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
                subtitle,
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

// ── Tarjeta de plan seleccionable ─────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final String label;
  final String price;
  final String badge;
  final Color badgeColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.price,
    required this.badge,
    required this.badgeColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.ocre.withOpacity(0.24),
                    AppColors.terracota.withOpacity(0.14),
                  ],
                )
              : null,
          color: isSelected ? null : AppColors.marronProfundo,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.ocre
                : AppColors.cremaPergamino.withOpacity(0.12),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: badgeColor.withOpacity(0.6)),
              ),
              child: Text(
                badge.toUpperCase(),
                style: GoogleFonts.lato(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.cremaPergamino.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.cremaPergamino,
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 18,
              color: isSelected
                  ? AppColors.ocre
                  : AppColors.cremaPergamino.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}
