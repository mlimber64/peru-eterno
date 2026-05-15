import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../services/wikipedia_service.dart';
import 'premium_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;
    final isPremium = context.watch<PremiumProvider>().isPremium;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 80),
          children: [
            // Header
            Text(
              context.read<LanguageProvider>().t('settings.eyebrow'),
              style: GoogleFonts.lato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.ocre,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.read<LanguageProvider>().t('settings.title'),
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.cremaPergamino,
              ),
            ),
            const SizedBox(height: 32),

            // ── Language ─────────────────────────────────────────────────
            _sectionLabel(
                context.read<LanguageProvider>().t('settings.language')),
            _LanguageSelector(lang: lang),
            const SizedBox(height: 28),

            // ── Premium ──────────────────────────────────────────────────
            _sectionLabel(
                context.read<LanguageProvider>().t('settings.premium')),
            if (isPremium)
              _InfoCard(
                icon: Icons.workspace_premium_rounded,
                title: context
                    .read<LanguageProvider>()
                    .t('settings.premium_active'),
                subtitle: context
                    .read<LanguageProvider>()
                    .t('settings.premium_active_subtitle'),
                color: AppColors.ocre,
              )
            else
              _ActionCard(
                icon: Icons.star_rounded,
                title: context.read<LanguageProvider>().t('settings.upgrade'),
                subtitle: context
                    .read<LanguageProvider>()
                    .t('settings.upgrade_subtitle'),
                color: AppColors.ocre,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PremiumScreen())),
              ),
            const SizedBox(height: 28),

            // ── Storage ───────────────────────────────────────────────────
            _sectionLabel(
                context.read<LanguageProvider>().t('settings.storage')),
            _ActionCard(
              icon: Icons.delete_sweep_rounded,
              title: context.read<LanguageProvider>().t('settings.clear_cache'),
              subtitle: context
                  .read<LanguageProvider>()
                  .t('settings.clear_cache_subtitle'),
              color: AppColors.textOnDarkMuted,
              onTap: () async {
                await WikipediaService.instance.clearCache();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context
                          .read<LanguageProvider>()
                          .t('settings.cache_cleared')),
                      backgroundColor: AppColors.marronProfundo,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.history_toggle_off_rounded,
              title:
                  context.read<LanguageProvider>().t('settings.clear_history'),
              subtitle: context
                  .read<LanguageProvider>()
                  .t('settings.clear_history_subtitle'),
              color: AppColors.textOnDarkMuted,
              onTap: () {
                context.read<HistoryProvider>().clear();
              },
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.favorite_border_rounded,
              title: context
                  .read<LanguageProvider>()
                  .t('settings.clear_favorites'),
              subtitle: context
                  .read<LanguageProvider>()
                  .t('settings.clear_favorites_subtitle'),
              color: AppColors.textOnDarkMuted,
              onTap: () async {
                // Clear all favorites one by one
                final provider = context.read<FavoritesProvider>();
                for (final id in Set.of(provider.favorites)) {
                  await provider.toggle(id);
                }
              },
            ),
            const SizedBox(height: 28),

            // ── About ─────────────────────────────────────────────────────
            _sectionLabel(context.read<LanguageProvider>().t('settings.about')),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.marronProfundo,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.cremaPergamino.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.read<LanguageProvider>().t('app.name'),
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cremaPergamino,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'v1.0.0',
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: AppColors.cremaPergamino.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.read<LanguageProvider>().t('settings.about_text'),
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: AppColors.cremaPergamino.withOpacity(0.55),
                      height: 1.55,
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

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: GoogleFonts.lato(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.cremaPergamino.withOpacity(0.35),
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ── Language selector ─────────────────────────────────────────────────────────

class _LanguageSelector extends StatelessWidget {
  final String lang;
  const _LanguageSelector({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: LanguageProvider.supportedLanguages.map((l) {
        final isActive = l['code'] == lang;
        return Expanded(
          child: GestureDetector(
            onTap: () =>
                context.read<LanguageProvider>().changeLanguage(l['code']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.ocre.withOpacity(0.15)
                    : AppColors.marronProfundo,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive
                      ? AppColors.ocre.withOpacity(0.6)
                      : AppColors.cremaPergamino.withOpacity(0.08),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(l['flag']!, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(
                    l['label']!,
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? AppColors.ocre
                          : AppColors.cremaPergamino.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Card widgets ──────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.marronProfundo,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.cremaPergamino.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cremaPergamino.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: AppColors.cremaPergamino.withOpacity(0.35),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.cremaPergamino.withOpacity(0.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.lato(
                  fontSize: 12,
                  color: color.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
