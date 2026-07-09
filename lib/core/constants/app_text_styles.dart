import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get displayTitle => GoogleFonts.playfairDisplay(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: AppColors.ocre,
        letterSpacing: 4,
      );

  static TextStyle get appBarTitle => GoogleFonts.playfairDisplay(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.cremaPergamino,
        letterSpacing: 3,
      );

  static TextStyle get eraTitle => GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get eraTitleLarge => GoogleFonts.playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get eraSubtitle => GoogleFonts.playfairDisplay(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        fontStyle: FontStyle.italic,
      );

  static TextStyle get eraPeriod => GoogleFonts.lato(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.ocre,
        letterSpacing: 1.5,
      );

  static TextStyle get bodyText => GoogleFonts.lato(
        fontSize: 15,
        color: AppColors.textPrimary,
        height: 1.7,
      );

  static TextStyle get bodyTextSmall => GoogleFonts.lato(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.6,
      );

  static TextStyle get buttonText => GoogleFonts.lato(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      );

  static TextStyle get tagline => GoogleFonts.lato(
        fontSize: 15,
        color: AppColors.cremaPergamino,
        letterSpacing: 3,
        fontWeight: FontWeight.w300,
      );

  static TextStyle get sectionHeader => GoogleFonts.playfairDisplay(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.marronOscuro,
      );

  static TextStyle get premiumPrice => GoogleFonts.playfairDisplay(
        fontSize: 42,
        fontWeight: FontWeight.bold,
        color: AppColors.ocre,
      );
}
