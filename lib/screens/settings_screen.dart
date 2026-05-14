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
              _eyebrow(lang),
              style: GoogleFonts.lato(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.ocre,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _title(lang),
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.cremaPergamino,
              ),
            ),
            const SizedBox(height: 32),

            // ── Language ─────────────────────────────────────────────────
            _sectionLabel(_langSection(lang)),
            _LanguageSelector(lang: lang),
            const SizedBox(height: 28),

            // ── Premium ──────────────────────────────────────────────────
            _sectionLabel('PREMIUM'),
            if (isPremium)
              _InfoCard(
                icon: Icons.workspace_premium_rounded,
                title: _activeTitle(lang),
                subtitle: _activeSubtitle(lang),
                color: AppColors.ocre,
              )
            else
              _ActionCard(
                icon: Icons.star_rounded,
                title: _upgradeTitle(lang),
                subtitle: _upgradeSubtitle(lang),
                color: AppColors.ocre,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PremiumScreen())),
              ),
            const SizedBox(height: 28),

            // ── Storage ───────────────────────────────────────────────────
            _sectionLabel(_storageSection(lang)),
            _ActionCard(
              icon: Icons.delete_sweep_rounded,
              title: _clearCacheTitle(lang),
              subtitle: _clearCacheSubtitle(lang),
              color: AppColors.textOnDarkMuted,
              onTap: () async {
                await WikipediaService.instance.clearCache();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_cacheClearedMsg(lang)),
                      backgroundColor: AppColors.marronProfundo,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.history_toggle_off_rounded,
              title: _clearHistoryTitle(lang),
              subtitle: _clearHistorySubtitle(lang),
              color: AppColors.textOnDarkMuted,
              onTap: () {
                context.read<HistoryProvider>().clear();
              },
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.favorite_border_rounded,
              title: _clearFavoritesTitle(lang),
              subtitle: _clearFavoritesSubtitle(lang),
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
            _sectionLabel(_aboutSection(lang)),
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
                    'Perú Eterno',
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
                    _aboutText(lang),
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

  String _eyebrow(String lang) => switch (lang) {
        'en' => 'PREFERENCES',
        'it' => 'PREFERENZE',
        _ => 'PREFERENCIAS',
      };
  String _title(String lang) => switch (lang) {
        'en' => 'Settings',
        'it' => 'Impostazioni',
        _ => 'Ajustes',
      };
  String _langSection(String lang) => switch (lang) {
        'en' => 'LANGUAGE',
        'it' => 'LINGUA',
        _ => 'IDIOMA',
      };
  String _storageSection(String lang) => switch (lang) {
        'en' => 'STORAGE',
        'it' => 'ARCHIVIAZIONE',
        _ => 'ALMACENAMIENTO',
      };
  String _aboutSection(String lang) => switch (lang) {
        'en' => 'ABOUT',
        'it' => 'INFO',
        _ => 'ACERCA DE',
      };
  String _activeTitle(String lang) => switch (lang) {
        'en' => 'Premium active',
        'it' => 'Premium attivo',
        _ => 'Premium activo',
      };
  String _activeSubtitle(String lang) => switch (lang) {
        'en' => 'All content unlocked',
        'it' => 'Tutto il contenuto sbloccato',
        _ => 'Todo el contenido desbloqueado',
      };
  String _upgradeTitle(String lang) => switch (lang) {
        'en' => 'Upgrade to Premium',
        'it' => 'Passa a Premium',
        _ => 'Mejorar a Premium',
      };
  String _upgradeSubtitle(String lang) => switch (lang) {
        'en' => 'Unlock all eras and content',
        'it' => 'Sblocca tutte le ere e i contenuti',
        _ => 'Desbloquea todas las eras y contenido',
      };
  String _clearCacheTitle(String lang) => switch (lang) {
        'en' => 'Clear Wikipedia cache',
        'it' => 'Svuota cache Wikipedia',
        _ => 'Limpiar caché Wikipedia',
      };
  String _clearCacheSubtitle(String lang) => switch (lang) {
        'en' => 'Force re-download of all articles',
        'it' => 'Forza il riscariamento degli articoli',
        _ => 'Fuerza la re-descarga de artículos',
      };
  String _clearHistoryTitle(String lang) => switch (lang) {
        'en' => 'Clear navigation history',
        'it' => 'Cancella cronologia',
        _ => 'Limpiar historial',
      };
  String _clearHistorySubtitle(String lang) => switch (lang) {
        'en' => 'Remove "continue exploring" items',
        'it' => 'Rimuovi elementi "continua a esplorare"',
        _ => 'Elimina elementos de "continuar explorando"',
      };
  String _clearFavoritesTitle(String lang) => switch (lang) {
        'en' => 'Clear all favorites',
        'it' => 'Cancella tutti i preferiti',
        _ => 'Eliminar todos los guardados',
      };
  String _clearFavoritesSubtitle(String lang) => switch (lang) {
        'en' => 'This cannot be undone',
        'it' => 'Questa azione non può essere annullata',
        _ => 'Esta acción no se puede deshacer',
      };
  String _cacheClearedMsg(String lang) => switch (lang) {
        'en' => 'Cache cleared',
        'it' => 'Cache svuotata',
        _ => 'Caché limpiado',
      };
  String _aboutText(String lang) => switch (lang) {
        'en' =>
          'A cultural encyclopedia about Peru\'s history, traditions, and people. Content powered by Wikipedia (CC BY-SA).',
        'it' =>
          'Un\'enciclopedia culturale sulla storia, le tradizioni e le persone del Perù. Contenuto fornito da Wikipedia (CC BY-SA).',
        _ =>
          'Una enciclopedia cultural sobre la historia, tradiciones y personas del Perú. Contenido proveniente de Wikipedia (CC BY-SA).',
      };
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
            border: Border.all(
                color: AppColors.cremaPergamino.withOpacity(0.06)),
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
                  size: 18,
                  color: AppColors.cremaPergamino.withOpacity(0.2)),
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
