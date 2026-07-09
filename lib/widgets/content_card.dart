import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/category_config.dart';
import '../core/navigation/app_navigation.dart';
import '../models/content_item.dart';
import '../providers/language_provider.dart';

class ContentCard extends StatelessWidget {
  final ContentItem item;
  final int animationIndex;

  const ContentCard({
    super.key,
    required this.item,
    this.animationIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = CategoryConfigs.colorOf(item.category);
    final icon = CategoryConfigs.iconOf(item.category);
    final t = context.watch<LanguageProvider>().t;

    return GestureDetector(
      onTap: () => AppNavigation.openContent(context, item),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.85),
              color.withOpacity(0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Background pattern
              Positioned(
                right: -12,
                bottom: -12,
                child: Icon(
                  icon,
                  size: 70,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      item.localizedTitle(t),
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: 400.ms,
          delay: Duration(milliseconds: 60 * animationIndex),
        )
        .slideX(
          begin: 0.15,
          end: 0,
          duration: 400.ms,
          delay: Duration(milliseconds: 60 * animationIndex),
          curve: Curves.easeOut,
        );
  }
}
