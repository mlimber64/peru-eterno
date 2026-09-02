import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/credits_data.dart';
import '../providers/language_provider.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.cremaPergamino,
        elevation: 0,
        title: Text(
          t('credits.title'),
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.cremaPergamino,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              t('credits.eyebrow'),
              style: GoogleFonts.lato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.ocre,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t('credits.intro'),
              style: GoogleFonts.lato(
                fontSize: 13.5,
                color: AppColors.cremaPergamino.withValues(alpha: 0.6),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),

            // ── Personajes (Wikimedia) ──────────────────────────────────
            _SectionHeader(
              title: t('credits.images_title'),
              subtitle: t('credits.images_intro'),
            ),
            const SizedBox(height: 12),
            ...CreditsData.personajes.map((c) => _CreditTile(credit: c)),

            const SizedBox(height: 28),

            // ── Gastronomía (Wikimedia) ─────────────────────────────────
            _SectionHeader(
              title: t('credits.food_title'),
              subtitle: t('credits.food_intro'),
            ),
            const SizedBox(height: 12),
            ...CreditsData.gastronomia.map((c) => _CreditTile(credit: c)),

            const SizedBox(height: 28),

            // ── Geografía (Wikimedia) ───────────────────────────────────
            _SectionHeader(
              title: t('credits.geo_title'),
              subtitle: t('credits.geo_intro'),
            ),
            const SizedBox(height: 12),
            ...CreditsData.geografia.map((c) => _CreditTile(credit: c)),

            const SizedBox(height: 28),

            // ── Música (mixto) ──────────────────────────────────────────
            _SectionHeader(
              title: t('credits.music_title'),
              subtitle: t('credits.music_intro'),
            ),
            const SizedBox(height: 12),
            ...CreditsData.musica.map((c) => _CreditTile(credit: c)),

            const SizedBox(height: 28),

            // ── Etapas (IA) ─────────────────────────────────────────────
            _SectionHeader(
              title: t('credits.stages_title'),
              subtitle: t('credits.stages_intro'),
            ),
            const SizedBox(height: 12),
            ...CreditsData.etapas.map((c) => _CreditTile(credit: c)),

            const SizedBox(height: 28),

            // ── Textos ──────────────────────────────────────────────────
            _SectionHeader(
              title: t('credits.text_title'),
              subtitle: t('credits.text_intro'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 16, color: AppColors.ocre),
            const SizedBox(width: 10),
            Text(
              title.toUpperCase(),
              style: GoogleFonts.lato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.cremaPergamino,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 13),
          child: Text(
            subtitle,
            style: GoogleFonts.lato(
              fontSize: 12,
              color: AppColors.cremaPergamino.withValues(alpha: 0.4),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreditTile extends StatelessWidget {
  final ImageCredit credit;
  const _CreditTile({required this.credit});

  Color _licenseColor() {
    switch (credit.license) {
      case CreditLicense.publicDomain:
        return const Color(0xFF2D6A4F);
      case CreditLicense.ccBySa4:
      case CreditLicense.ccBySa3:
      case CreditLicense.ccBySa2:
      case CreditLicense.ccBy3:
        return AppColors.ocre;
      case CreditLicense.aiGenerated:
        return AppColors.terracota;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.read<LanguageProvider>().t;
    final licenseColor = _licenseColor();
    final hasSource = credit.sourceUrl != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.marronProfundo,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: hasSource ? () => _openSource(context) : null,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.cremaPergamino.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        credit.title,
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cremaPergamino.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${credit.author} · ${credit.year}',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: AppColors.cremaPergamino.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: licenseColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: licenseColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              t('credits.license_${credit.license.name}'),
                              style: GoogleFonts.lato(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: licenseColor,
                              ),
                            ),
                          ),
                          if (hasSource) ...[
                            const SizedBox(width: 10),
                            Text(
                              t('credits.view_source'),
                              style: GoogleFonts.lato(
                                fontSize: 11,
                                color: AppColors.cremaPergamino.withValues(alpha: 0.35),
                                decoration: TextDecoration.underline,
                                decorationColor:
                                    AppColors.cremaPergamino.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasSource)
                  Icon(Icons.open_in_new_rounded,
                      size: 16,
                      color: AppColors.cremaPergamino.withValues(alpha: 0.25)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSource(BuildContext context) async {
    final uri = Uri.tryParse(credit.sourceUrl!);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(credit.sourceUrl!),
          backgroundColor: AppColors.marronProfundo,
        ),
      );
    }
  }
}
