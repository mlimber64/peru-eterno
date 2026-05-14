import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/language_provider.dart';
import '../screens/premium_screen.dart';

class PremiumLockOverlay extends StatelessWidget {
  final Widget child;

  const PremiumLockOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.marronOscuro.withOpacity(0.78),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PremiumScreen(),
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ocre, width: 1.5),
                        color: AppColors.marronOscuro.withOpacity(0.6),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: AppColors.ocre,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t('premium.locked_label'),
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 13,
                        color: AppColors.cremaPergamino,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('premium.tap_to_unlock'),
                      style: GoogleFonts.lato(
                        fontSize: 11,
                        color: AppColors.ocre,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
