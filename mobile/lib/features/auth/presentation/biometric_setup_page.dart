import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/feedback.dart';
import '../application/auth_controller.dart';

/// Oferta de acceso biométrico tras configurar el PIN. Siempre se puede omitir.
class BiometricSetupPage extends ConsumerStatefulWidget {
  const BiometricSetupPage({super.key, this.onContinuar});

  final VoidCallback? onContinuar;

  @override
  ConsumerState<BiometricSetupPage> createState() => _BiometricSetupPageState();
}

class _BiometricSetupPageState extends ConsumerState<BiometricSetupPage> {
  String _etiqueta = 'Biometría';

  @override
  void initState() {
    super.initState();
    ref.read(biometricServiceProvider).etiqueta.then((v) {
      if (mounted) setState(() => _etiqueta = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Padding(
              padding: const EdgeInsets.all(Gap.xl),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.10),
                    ),
                    child: const Icon(Icons.fingerprint_rounded, size: 70, color: AppColors.primary),
                  ),
                  Gap.h32,
                  Text('Entra más rápido con $_etiqueta',
                      textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                  Gap.h12,
                  Text(
                    'Activa el acceso biométrico y olvídate de escribir la contraseña cada vez. '
                    'Puedes desactivarlo cuando quieras desde Seguridad.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Gap.h24,
                  const InfoBanner(
                    mensaje: 'Tu huella o rostro nunca sale del dispositivo: '
                        'solo guardamos una llave cifrada ligada a este teléfono.',
                    icono: Icons.privacy_tip_outlined,
                  ),
                  const Spacer(),
                  AppButton(
                    label: 'Activar $_etiqueta',
                    icono: Icons.fingerprint_rounded,
                    cargando: auth.cargando,
                    onPressed: () async {
                      final ok = await ref.read(authControllerProvider.notifier).activarBiometria();
                      if (!context.mounted) return;
                      if (ok) {
                        Aviso.exito(context, 'Acceso biométrico activado');
                        widget.onContinuar?.call();
                      } else {
                        Aviso.info(context, 'No se pudo activar. Puedes intentarlo más tarde.');
                      }
                    },
                  ),
                  Gap.h12,
                  TextButton(
                    onPressed: widget.onContinuar,
                    child: const Text('Ahora no'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
