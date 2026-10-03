import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Mensajes efímeros con estilo de marca.
abstract final class Aviso {
  static void exito(BuildContext context, String mensaje) =>
      _mostrar(context, mensaje, AppColors.success, Icons.check_circle_outline);

  static void error(BuildContext context, String mensaje) =>
      _mostrar(context, mensaje, AppColors.danger, Icons.error_outline);

  static void info(BuildContext context, String mensaje) =>
      _mostrar(context, mensaje, AppColors.navy, Icons.info_outline);

  static void _mostrar(BuildContext context, String mensaje, Color color, IconData icono) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(icono, color: Colors.white, size: 20),
              Gap.w12,
              Expanded(
                child: Text(mensaje, style: const TextStyle(color: Colors.white, fontSize: 14.5)),
              ),
            ],
          ),
        ),
      );
  }
}

/// Banner informativo embebido (avisos de seguridad, estados, etc.).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.mensaje,
    this.icono = Icons.info_outline,
    this.color = AppColors.info,
    this.fondo,
    this.titulo,
  });

  const InfoBanner.exito({super.key, required this.mensaje, this.titulo})
      : icono = Icons.verified_outlined,
        color = AppColors.success,
        fondo = AppColors.successSoft;

  const InfoBanner.alerta({super.key, required this.mensaje, this.titulo})
      : icono = Icons.warning_amber_rounded,
        color = AppColors.warning,
        fondo = AppColors.warningSoft;

  const InfoBanner.error({super.key, required this.mensaje, this.titulo})
      : icono = Icons.error_outline,
        color = AppColors.danger,
        fondo = AppColors.dangerSoft;

  final String mensaje;
  final String? titulo;
  final IconData icono;
  final Color color;
  final Color? fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: fondo ?? color.withValues(alpha: 0.08),
        borderRadius: Radii.brMd,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 20),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titulo != null)
                  Text(titulo!,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: color, fontWeight: FontWeight.w700)),
                Text(
                  mensaje,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
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

/// Fila de "sello de seguridad" que da confianza en pantallas sensibles.
class SelloSeguridad extends StatelessWidget {
  const SelloSeguridad({super.key, this.texto = 'Conexión cifrada de extremo a extremo'});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
