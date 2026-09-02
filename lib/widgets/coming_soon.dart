import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/language_provider.dart';

/// Feedback compartido para el contenido bloqueado como "Próximamente"
/// (personajes, tradiciones, gastronomía, música, geografía en esta primera
/// versión — ver [CategoryConfigs.isComingSoon]). No navega a ningún lado:
/// solo confirma al usuario que el toque fue intencional y que el contenido
/// real llegará más adelante.
void showComingSoonSnackBar(BuildContext context) {
  final t = context.read<LanguageProvider>().t;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        // El color del texto va explícito: por defecto el SnackBar usa el del
        // tema (pensado para su fondo oscuro estándar) y sobre este marrón
        // apagado quedaba casi ilegible. Se añaden también el borde en ocre y
        // algo más de aire para que se lea como un aviso y no como un error.
        content: Text(
          t('coming_soon.message'),
          style: const TextStyle(
            color: AppColors.cremaPergamino,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        backgroundColor: AppColors.marronProfundo,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.ocre.withValues(alpha: 0.45)),
        ),
      ),
    );
}
