import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Estructura común de las pantallas del módulo de inicio:
/// cabecera con degradado de marca + hoja blanca con el contenido.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.titulo,
    required this.children,
    this.subtitulo,
    this.mostrarVolver = true,
    this.onVolver,
    this.accionCabecera,
    this.pie,
    this.icono,
    this.paso,
    this.totalPasos,
  });

  final String titulo;
  final String? subtitulo;
  final List<Widget> children;
  final bool mostrarVolver;
  final VoidCallback? onVolver;
  final Widget? accionCabecera;
  final Widget? pie;
  final IconData? icono;
  final int? paso;
  final int? totalPasos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Cabecera decorativa.
          Container(
            height: 230,
            decoration: const BoxDecoration(gradient: AppColors.brandGradient),
            child: CustomPaint(painter: _OndasPainter(), size: Size.infinite),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.lg, 0),
                  child: Row(
                    children: [
                      if (mostrarVolver)
                        IconButton(
                          onPressed: onVolver ?? () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          tooltip: 'Volver',
                        )
                      else
                        const SizedBox(width: Gap.sm),
                      const Spacer(),
                      ?accionCabecera,
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: kMaxContentWidth + 40),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, Gap.xl),
                        children: [
                          if (paso != null && totalPasos != null) ...[
                            _Pasos(paso: paso!, total: totalPasos!),
                            Gap.h24,
                          ],
                          if (icono != null) ...[
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: Radii.brLg,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                              ),
                              child: Icon(icono, color: Colors.white, size: 30),
                            ),
                            Gap.h16,
                          ],
                          Text(
                            titulo,
                            style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
                          ),
                          if (subtitulo != null) ...[
                            Gap.h8,
                            Text(
                              subtitulo!,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                            ),
                          ],
                          Gap.h24,
                          Container(
                            padding: const EdgeInsets.all(Gap.xl),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: Radii.brXl,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.navy.withValues(alpha: 0.10),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: children,
                            ),
                          ),
                          if (pie != null) ...[Gap.h24, pie!],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pasos extends StatelessWidget {
  const _Pasos({required this.paso, required this.total});

  final int paso;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 1; i <= total; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              decoration: BoxDecoration(
                color: i <= paso ? Colors.white : Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < total) const SizedBox(width: 6),
        ],
        Gap.w12,
        Text('$paso/$total',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Ondas sutiles en la cabecera (sin assets).
class _OndasPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.12), 90, paint);
    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.85), 70, paint);
    canvas.drawCircle(Offset(size.width * 0.70, size.height * 0.95), 40,
        Paint()..color = Colors.white.withValues(alpha: 0.05));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
