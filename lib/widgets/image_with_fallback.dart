import 'package:flutter/material.dart';

class ImageWithFallback extends StatelessWidget {
  final String assetPath;
  final Color fallbackColor;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallbackIcon;

  /// Si se proporciona, reemplaza por completo el placeholder por defecto
  /// (gradiente + icono) cuando el asset no carga. Útil para fallbacks
  /// artísticos a medida como [CaralPlaceholder].
  final Widget? fallbackOverride;

  const ImageWithFallback({
    super.key,
    required this.assetPath,
    required this.fallbackColor,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallbackIcon,
    this.fallbackOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        if (fallbackOverride != null) {
          return SizedBox(
            width: width,
            height: height,
            child: fallbackOverride,
          );
        }
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                fallbackColor,
                fallbackColor.withOpacity(0.6),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Subtle pattern overlay
              Positioned.fill(
                child: CustomPaint(painter: _PatternPainter(fallbackColor)),
              ),
              Center(
                child: fallbackIcon ??
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white.withOpacity(0.5),
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ilustración IA',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PatternPainter extends CustomPainter {
  final Color color;
  _PatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1;
    const spacing = 20.0;
    for (double x = 0; x < size.width + size.height; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(0, x), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
