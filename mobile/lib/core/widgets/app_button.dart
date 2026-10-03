import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Botón principal con estado de carga integrado.
/// Mientras `cargando` es true se bloquea para evitar doble envío.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.cargando = false,
    this.icono,
    this.expandido = true,
    this.variante = BotonVariante.primario,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool cargando;
  final IconData? icono;
  final bool expandido;
  final BotonVariante variante;

  @override
  Widget build(BuildContext context) {
    final habilitado = onPressed != null && !cargando;

    final hijo = cargando
        ? const SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icono != null) ...[Icon(icono, size: 20), Gap.w8],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final boton = switch (variante) {
      BotonVariante.primario => _Degradado(habilitado: habilitado, onPressed: onPressed, child: hijo),
      BotonVariante.secundario => OutlinedButton(onPressed: habilitado ? onPressed : null, child: hijo),
      BotonVariante.peligro => FilledButton(
          onPressed: habilitado ? onPressed : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: hijo,
        ),
    };

    return expandido ? SizedBox(width: double.infinity, child: boton) : boton;
  }
}

enum BotonVariante { primario, secundario, peligro }

class _Degradado extends StatelessWidget {
  const _Degradado({required this.habilitado, required this.onPressed, required this.child});

  final bool habilitado;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: habilitado ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: Radii.brMd,
          boxShadow: habilitado
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: FilledButton(
          onPressed: habilitado ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shadowColor: Colors.transparent,
          ),
          child: child,
        ),
      ),
    );
  }
}
