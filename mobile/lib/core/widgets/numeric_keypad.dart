import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Teclado numérico propio para el PIN.
///
/// Se usa en vez del teclado del sistema por dos razones:
/// no deja rastro en el diccionario predictivo y permite integrar
/// el botón de biometría junto a los dígitos.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.biometricIcon = Icons.fingerprint,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final IconData biometricIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final fila in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(children: fila.map((d) => _Tecla(label: d, onTap: enabled ? () => _pulsar(d) : null)).toList()),
        Row(
          children: [
            onBiometric != null
                ? _Tecla(
                    icono: biometricIcon,
                    onTap: enabled ? onBiometric : null,
                    colorIcono: AppColors.primary,
                  )
                : const Expanded(child: SizedBox(height: 72)),
            _Tecla(label: '0', onTap: enabled ? () => _pulsar('0') : null),
            _Tecla(
              icono: Icons.backspace_outlined,
              onTap: enabled
                  ? () {
                      HapticFeedback.selectionClick();
                      onBackspace();
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  void _pulsar(String d) {
    HapticFeedback.selectionClick();
    onDigit(d);
  }
}

class _Tecla extends StatelessWidget {
  const _Tecla({this.label, this.icono, this.onTap, this.colorIcono});

  final String? label;
  final IconData? icono;
  final VoidCallback? onTap;
  final Color? colorIcono;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 64,
              child: Center(
                child: label != null
                    ? Text(
                        label!,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: onTap == null
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      )
                    : Icon(icono, size: 26, color: colorIcono ?? theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Puntos que representan los dígitos ya introducidos.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, required this.filled, this.error = false});

  final int length;
  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final activo = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 9),
          width: activo ? 16 : 14,
          height: activo ? 16 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: error
                ? AppColors.danger
                : activo
                    ? AppColors.primary
                    : Colors.transparent,
            border: Border.all(
              color: error
                  ? AppColors.danger
                  : activo
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.outline,
              width: 1.8,
            ),
          ),
        );
      }),
    );
  }
}
