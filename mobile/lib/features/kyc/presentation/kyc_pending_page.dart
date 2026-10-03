import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/application/auth_controller.dart';
import 'kyc_flow_page.dart';

/// Espera activa mientras compliance revisa el expediente.
/// Consulta el estado cada 5 s y continúa sola cuando se aprueba.
class KycPendingPage extends ConsumerStatefulWidget {
  const KycPendingPage({super.key});

  @override
  ConsumerState<KycPendingPage> createState() => _KycPendingPageState();
}

class _KycPendingPageState extends ConsumerState<KycPendingPage> {
  Timer? _timer;
  bool _consultando = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _consultar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _consultar() async {
    if (_consultando) return;
    _consultando = true;
    try {
      final estado = await ref.read(kycRepositoryProvider).estado();
      if (estado.status != 'in_review') {
        _timer?.cancel();
        await ref.read(authControllerProvider.notifier).refrescarUsuario();
      }
    } catch (_) {
      // Reintento silencioso en el siguiente tick.
    } finally {
      _consultando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;
    final rechazado = user?.kycStatus == 'rejected';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Padding(
              padding: const EdgeInsets.all(Gap.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (!rechazado)
                          const SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        Icon(
                          rechazado ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
                          size: 52,
                          color: rechazado ? AppColors.danger : AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  Gap.h32,
                  Text(
                    rechazado ? 'No pudimos verificarte' : 'Estamos revisando tus documentos',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  Gap.h12,
                  Text(
                    rechazado
                        ? 'Revisa que las fotos sean nítidas y que el documento esté vigente. '
                            'Puedes volver a intentarlo ahora mismo.'
                        : 'Normalmente tarda menos de 10 minutos. Te avisaremos por notificación '
                            'en cuanto tu cuenta esté lista para enviar dinero.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Gap.h32,
                  if (rechazado)
                    AppButton(
                      label: 'Reintentar verificación',
                      icono: Icons.refresh_rounded,
                      onPressed: () => ref.read(authControllerProvider.notifier).refrescarUsuario(),
                    )
                  else
                    AppButton(
                      label: 'Actualizar estado',
                      variante: BotonVariante.secundario,
                      icono: Icons.sync_rounded,
                      onPressed: _consultar,
                    ),
                  Gap.h8,
                  TextButton(
                    onPressed: () => ref.read(authControllerProvider.notifier).cerrarSesion(),
                    child: const Text('Cerrar sesión'),
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
