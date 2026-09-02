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
        content: Text(t('coming_soon.message')),
        backgroundColor: AppColors.marronProfundo,
        behavior: SnackBarBehavior.floating,
      ),
    );
}
