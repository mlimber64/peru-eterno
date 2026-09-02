import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Placeholder artístico para la era **Caral**, que no dispone de fotografía.
///
/// En lugar de un recuadro plano, dibuja con [CustomPainter] una composición
/// minimalista y mística: la silueta de una **pirámide truncada andina**
/// (huaca escalonada de Caral) coronada por un sol naciente, sobre la que
/// "cuelgan" las cuerdas de un **quipu**. Todo trazado con líneas finas en el
/// dorado de la era sobre el fondo cacao de la app, para que parezca una
/// decisión de diseño deliberada y no un error de carga.
///
/// Uso típico (como fondo de una card o de un hero):
/// ```dart
/// const CaralPlaceholder(); // se expande al tamaño disponible
/// ```
class CaralPlaceholder extends StatelessWidget {
  /// Color de acento de la era (por defecto el dorado de Caral, #D4A854).
  final Color accentColor;

  /// Fondo base de la app (por defecto el negro cacao, #1A0F0A).
  final Color backgroundColor;

  /// Etiqueta opcional bajo la ilustración (ej. el nombre de la era).
  /// Si es `null` no se muestra ningún texto.
  final String? label;

  const CaralPlaceholder({
    super.key,
    this.accentColor = const Color(0xFFD4A854),
    this.backgroundColor = const Color(0xFF1A0F0A),
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Sutil viñeta radial para dar profundidad sin distraer.
        gradient: RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 1.1,
          colors: [
            Color.lerp(backgroundColor, accentColor, 0.06)!,
            backgroundColor,
          ],
        ),
      ),
      child: CustomPaint(
        painter: _CaralPainter(accentColor: accentColor),
        // Si hay label, lo colocamos con el mismo lenguaje tipográfico fino.
        child: label == null
            ? const SizedBox.expand()
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    label!.toUpperCase(),
                    style: TextStyle(
                      color: accentColor.withValues(alpha: 0.75),
                      fontSize: 11,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _CaralPainter extends CustomPainter {
  final Color accentColor;

  const _CaralPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Trazo principal (contorno) y trazo tenue (detalles internos).
    final stroke = Paint()
      ..color = accentColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    final faint = Paint()
      ..color = accentColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final fill = Paint()
      ..color = accentColor.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    _drawSun(canvas, size, stroke, faint);
    _drawPyramid(canvas, w, h, stroke, fill);
    _drawQuipu(canvas, w, h, faint);
  }

  /// Sol/luna naciente: un círculo y unos rayos cortos sobre la cima.
  void _drawSun(Canvas canvas, Size size, Paint stroke, Paint faint) {
    final center = Offset(size.width * 0.5, size.height * 0.24);
    final radius = size.shortestSide * 0.085;

    canvas.drawCircle(center, radius, stroke);

    // Rayos radiales tenues, simétricos.
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final angle = (i / rays) * 2 * math.pi;
      final start = Offset(
        center.dx + radius * 1.35 * math.cos(angle),
        center.dy + radius * 1.35 * math.sin(angle),
      );
      final end = Offset(
        center.dx + radius * 1.75 * math.cos(angle),
        center.dy + radius * 1.75 * math.sin(angle),
      );
      canvas.drawLine(start, end, faint);
    }
  }

  /// Pirámide truncada andina de 4 plataformas escalonadas, centrada.
  void _drawPyramid(Canvas canvas, double w, double h, Paint stroke, Paint fill) {
    const steps = 4;
    final baseY = h * 0.82; // apoyo inferior
    final topY = h * 0.40; // cima truncada
    final baseHalf = w * 0.34; // medio ancho en la base
    final topHalf = w * 0.12; // medio ancho en la cima (truncada)

    final cx = w * 0.5;
    final stepH = (baseY - topY) / steps;

    final path = Path();

    // Construimos el perfil escalonado del lado izquierdo, subiendo,
    // y luego bajamos por el derecho en espejo: una silueta cerrada.
    final leftPoints = <Offset>[];
    final rightPoints = <Offset>[];

    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final half = baseHalf + (topHalf - baseHalf) * t;
      final y = baseY - stepH * i;

      // Punto exterior del escalón (esquina vertical).
      leftPoints.add(Offset(cx - half, y));
      rightPoints.add(Offset(cx + half, y));

      // Salvo en la cima, generamos la "huella" horizontal del escalón.
      if (i < steps) {
        final nextHalf =
            baseHalf + (topHalf - baseHalf) * ((i + 1) / steps);
        leftPoints.add(Offset(cx - nextHalf, y - stepH));
        rightPoints.add(Offset(cx + nextHalf, y - stepH));
      }
    }

    // Lado izquierdo (de abajo hacia arriba).
    path.moveTo(leftPoints.first.dx, leftPoints.first.dy);
    for (final p in leftPoints.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    // Cima truncada (de izquierda a derecha).
    path.lineTo(cx + topHalf, topY);
    // Lado derecho (de arriba hacia abajo).
    for (final p in rightPoints.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);

    // Acceso central: escalinata sugerida con líneas verticales finas.
    final stair = Paint()
      ..color = accentColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < steps; i++) {
      final y0 = baseY - stepH * i;
      final y1 = y0 - stepH;
      canvas.drawLine(Offset(cx - w * 0.03, y0), Offset(cx - w * 0.03, y1), stair);
      canvas.drawLine(Offset(cx + w * 0.03, y0), Offset(cx + w * 0.03, y1), stair);
    }

    // Línea de horizonte/suelo que ancla la huaca.
    canvas.drawLine(
      Offset(w * 0.08, baseY),
      Offset(w * 0.92, baseY),
      stroke..strokeWidth = 1.2,
    );
  }

  /// Quipu: una cuerda madre horizontal de la que cuelgan cuerdas con nudos.
  void _drawQuipu(Canvas canvas, double w, double h, Paint faint) {
    final ropeY = h * 0.115;
    final startX = w * 0.30;
    final endX = w * 0.70;

    // Cuerda madre.
    canvas.drawLine(Offset(startX, ropeY), Offset(endX, ropeY), faint);

    // Cuerdas colgantes con un par de nudos (puntos) cada una.
    const cords = 6;
    final knot = Paint()
      ..color = accentColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < cords; i++) {
      final t = cords == 1 ? 0.5 : i / (cords - 1);
      final x = startX + (endX - startX) * t;
      // Longitud alterna para dar ritmo orgánico.
      final len = h * (0.05 + (i.isEven ? 0.05 : 0.02));
      canvas.drawLine(Offset(x, ropeY), Offset(x, ropeY + len), faint);

      // Nudos sobre la cuerda.
      canvas.drawCircle(Offset(x, ropeY + len * 0.55), 1.4, knot);
      if (i.isEven) {
        canvas.drawCircle(Offset(x, ropeY + len * 0.9), 1.4, knot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CaralPainter old) =>
      old.accentColor != accentColor;
}
