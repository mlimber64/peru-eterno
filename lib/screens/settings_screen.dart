import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/legal_document.dart';
import '../providers/daily_story_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/history_provider.dart';
import '../providers/language_provider.dart';
import '../providers/premium_provider.dart';
import '../services/account_data_service.dart';
import '../services/streak_notification_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/wikipedia_service.dart';
import 'account_screen.dart';
import 'credits_screen.dart';
import 'legal_screen.dart';
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

            // ── Credits ───────────────────────────────────────────────────
            _sectionLabel(
                context.read<LanguageProvider>().t('settings.credits')),
            _ActionCard(
              icon: Icons.public_rounded,
              title: context.read<LanguageProvider>().t('settings.credits'),
              subtitle: context
                  .read<LanguageProvider>()
                  .t('settings.credits_subtitle'),
              color: AppColors.ocre,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreditsScreen())),
            ),
            const SizedBox(height: 28),

            // ── Recordatorios ─────────────────────────────────────────────
            // La racha existía sin nada que trajera al usuario de vuelta al
            // día siguiente. El permiso se pide aquí, al activar, no al
            // arrancar la app.
            _sectionLabel(
                context.read<LanguageProvider>().t('settings.notifications')),
            const _StreakReminderCard(),
            const SizedBox(height: 28),

            // ── Cuenta ────────────────────────────────────────────────────
            // Sin correo vinculado, el progreso sincronizado es irrecuperable:
            // la identidad es anónima y vive en el almacenamiento de la app,
            // así que reinstalar genera otro user_id.
            _sectionLabel(
                context.read<LanguageProvider>().t('settings.account')),
            const _AccountCard(),
            const SizedBox(height: 28),

            // ── Tus datos ─────────────────────────────────────────────────
            // Vía de borrado exigida por Google Play ("Eliminación de datos
            // y de la cuenta") y por App Store. Borra el progreso local Y la
            // copia sincronizada en Supabase; ver AccountDataService.
            _sectionLabel(context.read<LanguageProvider>().t('settings.data')),
            _ActionCard(
              icon: Icons.delete_forever_rounded,
              title:
                  context.read<LanguageProvider>().t('settings.delete_data'),
              subtitle: context
                  .read<LanguageProvider>()
                  .t('settings.delete_data_subtitle'),
              color: AppColors.terracota,
              onTap: () => _confirmAndDeleteData(context),
            ),
            const SizedBox(height: 28),

            // ── Legal ─────────────────────────────────────────────────────
            // Play Console y App Store exigen que la política de privacidad
            // sea accesible desde dentro de la app, además de por una URL
            // pública (ver docs/, generado desde el mismo assets/legal/).
            _sectionLabel(context.read<LanguageProvider>().t('settings.legal')),
            _ActionCard(
              icon: Icons.privacy_tip_outlined,
              title: context
                  .read<LanguageProvider>()
                  .t('premium.legal_privacy'),
              subtitle: context
                  .read<LanguageProvider>()
                  .t('settings.privacy_subtitle'),
              color: AppColors.textOnDarkMuted,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalScreen(type: LegalDocType.privacy),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.gavel_rounded,
              title:
                  context.read<LanguageProvider>().t('premium.legal_terms'),
              subtitle: context
                  .read<LanguageProvider>()
                  .t('settings.terms_subtitle'),
              color: AppColors.textOnDarkMuted,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalScreen(type: LegalDocType.terms),
                ),
              ),
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
                    color: AppColors.cremaPergamino.withValues(alpha: 0.06)),
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
                      color: AppColors.cremaPergamino.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.read<LanguageProvider>().t('settings.about_text'),
                    style: GoogleFonts.lato(
                      fontSize: 13,
                      color: AppColors.cremaPergamino.withValues(alpha: 0.55),
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _AnonymousIdRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pide confirmación explícita y, si el usuario acepta, borra todos sus
  /// datos (locales y remotos). El diálogo enumera qué desaparece y qué se
  /// conserva: la suscripción y el idioma no se tocan, y así lo dicen
  /// también los Términos de Servicio.
  Future<void> _confirmAndDeleteData(BuildContext context) async {
    final t = context.read<LanguageProvider>().t;
    final service = context.read<AccountDataService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.marronProfundo,
        title: Text(
          t('settings.delete_data_title'),
          style: GoogleFonts.playfairDisplay(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: AppColors.cremaPergamino,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('settings.delete_data_body'),
              style: GoogleFonts.lato(
                fontSize: 13.5,
                color: AppColors.cremaPergamino.withValues(alpha: 0.7),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t('settings.delete_data_kept'),
              style: GoogleFonts.lato(
                fontSize: 12.5,
                color: AppColors.cremaPergamino.withValues(alpha: 0.45),
                height: 1.55,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              t('settings.delete_data_cancel'),
              style: GoogleFonts.lato(
                color: AppColors.cremaPergamino.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              t('settings.delete_data_cta'),
              style: GoogleFonts.lato(
                color: AppColors.terracota,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Barrera modal mientras corre el borrado: son varias llamadas de red y
    // escrituras a disco, y volver a pulsar dispararía un segundo borrado.
    // `navigator` se capturó ANTES del await de arriba (ver arriba en este
    // método), así que `navigator.context` sigue siendo válido aunque este
    // widget ya no esté montado. El analizador no puede demostrarlo y avisa
    // igualmente; el aviso se silencia aquí en vez de dejarlo permanente,
    // porque un warning que siempre está y siempre se ignora acaba tapando
    // a los que sí importan.
    showDialog<void>(
      // ignore: use_build_context_synchronously
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.marronProfundo,
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.ocre,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                t('settings.delete_data_working'),
                style: GoogleFonts.lato(
                  fontSize: 13.5,
                  color: AppColors.cremaPergamino.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final outcome = await service.deleteEverything();
    navigator.pop(); // Cierra la barrera modal.

    final message = switch (outcome) {
      AccountDeletionOutcome.full => t('settings.delete_data_done'),
      AccountDeletionOutcome.localOnly => t('settings.delete_data_local_only'),
      AccountDeletionOutcome.remoteFailed =>
        t('settings.delete_data_remote_failed'),
    };
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: outcome == AccountDeletionOutcome.remoteFailed
              ? AppColors.terracota
              : AppColors.marronProfundo,
          duration: const Duration(seconds: 6),
          // Flotante y con margen inferior: el SnackBar lo muestra el
          // ScaffoldMessenger raíz, así que anclado abajo queda tapado por la
          // barra de navegación del shell y se corta la última línea.
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
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
          color: AppColors.cremaPergamino.withValues(alpha: 0.35),
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ── Recordatorio de racha ─────────────────────────────────────────────────────

/// Interruptor del recordatorio diario.
///
/// Es `Stateful` porque el estado real no está en un provider: vive en el
/// servicio de notificaciones y en el permiso del sistema, que puede negarse.
/// Si Android rechaza el permiso, el interruptor vuelve a apagado en vez de
/// quedarse encendido prometiendo avisos que nunca llegarán.
class _StreakReminderCard extends StatefulWidget {
  const _StreakReminderCard();

  @override
  State<_StreakReminderCard> createState() => _StreakReminderCardState();
}

class _StreakReminderCardState extends State<_StreakReminderCard> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    final t = context.read<LanguageProvider>().t;
    final service = context.read<StreakNotificationService>();
    final daily = context.read<DailyStoryProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);

    var ok = true;
    if (value) {
      ok = await service.enable(alreadyReadToday: daily.isCompletedToday);
    } else {
      await service.disable();
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (value && !ok) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(t('notifications.permission_denied')),
            backgroundColor: AppColors.terracota,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            duration: const Duration(seconds: 5),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.read<LanguageProvider>().t;
    // `read` y no `watch`: el servicio no es un ChangeNotifier; quien
    // provoca el redibujado es el setState de _toggle.
    final service = context.read<StreakNotificationService>();
    final enabled = service.isEnabled;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.marronProfundo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cremaPergamino.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.ocre.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              size: 20,
              color: AppColors.ocre,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('settings.streak_reminder'),
                  style: GoogleFonts.lato(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cremaPergamino.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t('settings.streak_reminder_subtitle'),
                  style: GoogleFonts.lato(
                    fontSize: 12,
                    color: AppColors.cremaPergamino.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.ocre,
              ),
            )
          else
            Switch(
              value: enabled,
              onChanged: _toggle,
              activeThumbColor: AppColors.ocre,
              inactiveThumbColor: AppColors.cremaPergamino.withValues(alpha: 0.3),
            ),
        ],
      ),
    );
  }
}

// ── Cuenta ────────────────────────────────────────────────────────────────────

/// Tarjeta de cuenta: invita a vincular un correo si la sesión es anónima, o
/// muestra el correo vinculado si ya lo está.
///
/// Escucha `linkedEmail` para reflejar el cambio en cuanto se vincula, sin
/// tener que salir y volver a entrar a Ajustes.
class _AccountCard extends StatelessWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context) {
    final t = context.read<LanguageProvider>().t;
    final auth = context.read<SupabaseAuthService>();

    return ValueListenableBuilder<String?>(
      valueListenable: auth.linkedEmail,
      builder: (context, email, _) {
        if (email != null) {
          return _InfoCard(
            icon: Icons.verified_user_rounded,
            title: email,
            subtitle: t('settings.account_linked_subtitle'),
            color: AppColors.verdeAndino,
          );
        }
        return _ActionCard(
          icon: Icons.cloud_upload_rounded,
          title: t('settings.account_anonymous'),
          subtitle: t('settings.account_anonymous_subtitle'),
          color: AppColors.ocre,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountScreen()),
          ),
        );
      },
    );
  }
}

// ── Identificador anónimo ─────────────────────────────────────────────────────

/// Muestra (y permite copiar) el `user_id` de la sesión anónima.
///
/// No es decorativo: la política de privacidad remite justamente aquí para
/// que quien quiera ejercer sus derechos por email pueda decirnos de qué
/// cuenta habla — sin ese dato, una cuenta sin registro es irrastreable.
class _AnonymousIdRow extends StatelessWidget {
  const _AnonymousIdRow();

  @override
  Widget build(BuildContext context) {
    final t = context.read<LanguageProvider>().t;
    final auth = context.read<SupabaseAuthService>();

    return ValueListenableBuilder<String?>(
      valueListenable: auth.userId,
      builder: (context, userId, _) {
        final hasId = userId != null;
        return InkWell(
          onTap: hasId
              ? () async {
                  await Clipboard.setData(ClipboardData(text: userId));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(t('settings.user_id_copied')),
                        backgroundColor: AppColors.marronProfundo,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      ),
                    );
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('settings.user_id'),
                        style: GoogleFonts.lato(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.cremaPergamino.withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userId ?? t('settings.user_id_none'),
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          color: AppColors.cremaPergamino.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasId)
                  Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: AppColors.cremaPergamino.withValues(alpha: 0.3),
                  ),
              ],
            ),
          ),
        );
      },
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
                    ? AppColors.ocre.withValues(alpha: 0.15)
                    : AppColors.marronProfundo,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive
                      ? AppColors.ocre.withValues(alpha: 0.6)
                      : AppColors.cremaPergamino.withValues(alpha: 0.08),
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
                          : AppColors.cremaPergamino.withValues(alpha: 0.4),
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
        splashColor: color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.cremaPergamino.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
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
                        color: AppColors.cremaPergamino.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: AppColors.cremaPergamino.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.cremaPergamino.withValues(alpha: 0.2)),
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
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
                  color: color.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
