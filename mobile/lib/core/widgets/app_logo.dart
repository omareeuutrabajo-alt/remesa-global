import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Isotipo de la marca: un avión de papel dentro de una moneda.
/// Dibujado con `CustomPaint` para no depender de assets externos.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72, this.light = false});

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: light ? null : AppColors.brandGradient,
        color: light ? Colors.white : null,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: light ? 0.18 : 0.35),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _AvionPainter(color: light ? AppColors.primary : Colors.white),
      ),
    );
  }
}

class _AvionPainter extends CustomPainter {
  _AvionPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;

    // Cuerpo del avión de papel.
    final cuerpo = Path()
      ..moveTo(w * 0.22, h * 0.50)
      ..lineTo(w * 0.78, h * 0.26)
      ..lineTo(w * 0.56, h * 0.76)
      ..lineTo(w * 0.47, h * 0.57)
      ..close();
    canvas.drawPath(cuerpo, paint);

    // Ala inferior en tono atenuado.
    final ala = Path()
      ..moveTo(w * 0.47, h * 0.57)
      ..lineTo(w * 0.78, h * 0.26)
      ..lineTo(w * 0.50, h * 0.70)
      ..close();
    canvas.drawPath(ala, Paint()..color = color.withValues(alpha: 0.55));
  }

  @override
  bool shouldRepaint(covariant _AvionPainter old) => old.color != color;
}

/// Logo + nombre, para cabeceras.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.light = false, this.size = 34});

  final bool light;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : AppColors.navy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: size, light: light),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(children: [
            TextSpan(
              text: 'Remesa',
              style: TextStyle(
                fontSize: size * 0.52,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            TextSpan(
              text: 'Global',
              style: TextStyle(
                fontSize: size * 0.52,
                fontWeight: FontWeight.w300,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
