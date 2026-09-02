import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';

class AppLoadingState extends StatelessWidget {
  final double height;
  final Color color;
  final double strokeWidth;

  const AppLoadingState({
    super.key,
    this.height = 120,
    this.color = AppColors.ocre,
    this.strokeWidth = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: CircularProgressIndicator(
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final double iconSize;
  final Color iconColor;
  final Color titleColor;
  final Color? subtitleColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconSize = 56,
    this.iconColor = const Color(0x26F5E6C8),
    this.titleColor = const Color(0x4DF5E6C8),
    this.subtitleColor,
    this.titleStyle,
    this.subtitleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: titleStyle ??
                GoogleFonts.lato(
                  fontSize: 15,
                  color: titleColor,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: subtitleStyle ??
                  GoogleFonts.lato(
                    fontSize: 13,
                    color: subtitleColor ?? titleColor.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final double height;
  final IconData icon;
  final Color color;
  final String? message;

  const AppErrorState({
    super.key,
    this.height = 300,
    this.icon = Icons.error_outline,
    this.color = Colors.white38,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: message == null
            ? Icon(icon, color: color, size: 48)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(color: color),
                  ),
                ],
              ),
      ),
    );
  }
}
