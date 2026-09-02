import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';

/// A reusable cinematic card: image/gradient background + dark overlay + text.
class CinematicCard extends StatelessWidget {
  final String? assetImagePath;
  final String? networkImageUrl;
  final Color accentColor;
  final String title;
  final String? subtitle;
  final String? badge;
  final bool isPremium;
  final bool isComingSoon;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  /// Fondo a usar cuando NO hay imagen (asset ausente o con error). Si es
  /// `null` se usa el gradiente de acento por defecto. Permite inyectar un
  /// fallback artístico como [CaralPlaceholder].
  final Widget? imageFallback;

  const CinematicCard({
    super.key,
    this.assetImagePath,
    this.networkImageUrl,
    required this.accentColor,
    required this.title,
    this.subtitle,
    this.badge,
    this.isPremium = false,
    this.isComingSoon = false,
    this.onTap,
    this.width = double.infinity,
    this.height = 200,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.imageFallback,
  });

  /// Etiqueta combinada para lectores de pantalla: título + subtítulo +
  /// estado (bloqueado/próximamente), ya que el contenido visual interno se
  /// excluye del árbol de semántica para evitar que TalkBack/VoiceOver lo
  /// lea como varios nodos sueltos sin indicar que la tarjeta es tocable.
  String get _semanticLabel {
    final parts = <String>[
      if (badge != null && !isPremium && !isComingSoon) badge!,
      title,
      if (subtitle != null) subtitle!,
      if (isPremium) 'Premium',
      if (isComingSoon) 'Próximamente',
    ];
    return parts.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: _semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: ExcludeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image or gradient
                  _buildBackground(),
                  // Dark overlay (always present for readability)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.75),
                        ],
                        stops: const [0.35, 1.0],
                      ),
                    ),
                  ),
                  // Premium lock / coming-soon overlay
                  if (isPremium || isComingSoon)
                    Container(color: Colors.black.withOpacity(0.45)),
                  // Content
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (badge != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isComingSoon
                                    ? Colors.white.withOpacity(0.22)
                                    : accentColor.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                badge!,
                                style: GoogleFonts.lato(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            title,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle!,
                              style: GoogleFonts.lato(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.75),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // Premium / coming-soon icon
                  if (isPremium)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_rounded,
                            size: 14, color: AppColors.ocre),
                      ),
                    )
                  else if (isComingSoon)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.hourglass_top_rounded,
                            size: 14, color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    // Priority: asset image → network image → fallback (custom or gradient)
    if (assetImagePath != null) {
      return Image.asset(
        assetImagePath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    }
    if (networkImageUrl != null && networkImageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkImageUrl!,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildFallback(),
        placeholder: (_, __) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() => imageFallback ?? _buildGradient();

  Widget _buildGradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withOpacity(0.9),
            accentColor.withOpacity(0.4),
            Colors.black.withOpacity(0.8),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(painter: _DiagonalPatternPainter(accentColor)),
    );
  }
}

// Subtle diagonal line pattern for gradient placeholders
class _DiagonalPatternPainter extends CustomPainter {
  final Color color;
  const _DiagonalPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.08)
      ..strokeWidth = 1;

    const spacing = 20.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
          Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
