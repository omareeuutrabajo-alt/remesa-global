import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/feedback.dart';
import '../../auth/application/auth_controller.dart';
import '../../kyc/presentation/kyc_flow_page.dart';

/// Punto de llegada del módulo de inicio.
///
/// No es el dashboard definitivo de remesas: muestra el estado de la cuenta
/// y el panel de seguridad para demostrar que la sesión quedó establecida.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final limites = ref.watch(kycLimitsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(authControllerProvider.notifier).refrescarUsuario(),
          child: ListView(
            padding: const EdgeInsets.all(Gap.xl),
            children: [
              Row(
                children: [
                  const AppLogo(size: 40),
                  Gap.w12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hola,', style: theme.textTheme.bodySmall),
                        Text(user?.firstName ?? 'Usuario',
                            style: theme.textTheme.titleLarge, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Bloquear app',
                    onPressed: () => ref.read(authControllerProvider.notifier).bloquear(),
                    icon: const Icon(Icons.lock_outline_rounded),
                  ),
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(user?.initials ?? '?',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              Gap.h24,

              // Tarjeta de saldo / límites.
              Container(
                padding: const EdgeInsets.all(Gap.xl),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: Radii.brXl,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Disponible para enviar',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: Radii.brSm,
                          ),
                          child: Text(
                            user?.kycApproved == true ? 'Nivel ${user!.kycLevel}' : 'Sin verificar',
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    Gap.h8,
                    limites.when(
                      data: (l) => Text(
                        '\$${l.perTransaction.toStringAsFixed(0)}',
                        style: theme.textTheme.displaySmall?.copyWith(color: Colors.white),
                      ),
                      loading: () => const SizedBox(
                        height: 40,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        ),
                      ),
                      error: (_, _) => Text('—',
                          style: theme.textTheme.displaySmall?.copyWith(color: Colors.white)),
                    ),
                    Text('por transacción',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                    Gap.h16,
                    limites.maybeWhen(
                      data: (l) => Row(
                        children: [
                          _Limite(titulo: 'Diario', valor: '\$${l.daily.toStringAsFixed(0)}'),
                          Container(width: 1, height: 28, color: Colors.white24),
                          _Limite(titulo: 'Mensual', valor: '\$${l.monthly.toStringAsFixed(0)}'),
                        ],
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              Gap.h24,

              if (user?.kycApproved == true)
                const InfoBanner.exito(
                  titulo: 'Identidad verificada',
                  mensaje: 'Tu cuenta está lista para enviar dinero.',
                )
              else
                const InfoBanner.alerta(
                  titulo: 'Verificación pendiente',
                  mensaje: 'Completa tu verificación para desbloquear los envíos.',
                ),
              Gap.h24,

              Text('Seguridad de la cuenta', style: theme.textTheme.titleLarge),
              Gap.h12,
              _Opcion(
                icono: Icons.pin_outlined,
                titulo: 'PIN de acceso',
                subtitulo: user?.hasPin == true ? 'Configurado' : 'Sin configurar',
                activo: user?.hasPin == true,
              ),
              _Opcion(
                icono: Icons.fingerprint_rounded,
                titulo: 'Acceso biométrico',
                subtitulo: !auth.biometriaDisponible
                    ? 'No disponible en este dispositivo'
                    : auth.biometriaActiva
                        ? 'Activado'
                        : 'Desactivado',
                activo: auth.biometriaActiva,
                trailing: auth.biometriaDisponible
                    ? Switch(
                        value: auth.biometriaActiva,
                        onChanged: (v) async {
                          final notifier = ref.read(authControllerProvider.notifier);
                          if (v) {
                            final ok = await notifier.activarBiometria();
                            if (context.mounted && !ok) {
                              Aviso.info(context, 'No se pudo activar la biometría');
                            }
                          } else {
                            await notifier.desactivarBiometria();
                          }
                        },
                      )
                    : null,
              ),
              _Opcion(
                icono: Icons.verified_user_outlined,
                titulo: 'Verificación de identidad',
                subtitulo: switch (user?.kycStatus) {
                  'approved' => 'Aprobada',
                  'in_review' => 'En revisión',
                  'rejected' => 'Rechazada',
                  _ => 'Pendiente',
                },
                activo: user?.kycApproved == true,
              ),
              _Opcion(
                icono: Icons.devices_outlined,
                titulo: 'Dispositivos y sesiones',
                subtitulo: 'Revisa dónde iniciaste sesión',
                onTap: () => _mostrarSesiones(context, ref),
              ),
              Gap.h24,
              OutlinedButton.icon(
                onPressed: () => ref.read(authControllerProvider.notifier).cerrarSesion(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesión'),
              ),
              Gap.h8,
              TextButton(
                onPressed: () => ref
                    .read(authControllerProvider.notifier)
                    .cerrarSesion(todosLosDispositivos: true),
                child: const Text('Cerrar sesión en todos los dispositivos'),
              ),
              Gap.h24,
              Center(
                child: Text(
                  user != null ? 'Sesión iniciada como ${user.email}' : '',
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarSesiones(BuildContext context, WidgetRef ref) async {
    final sesiones = await ref.read(authRepositoryProvider).sessions();
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sesiones activas', style: Theme.of(context).textTheme.titleLarge),
              Gap.h16,
              if (sesiones.isEmpty)
                const Text('No hay otras sesiones abiertas.')
              else
                ...sesiones.map(
                  (s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_iphone_rounded),
                    title: Text(s['device_id']?.toString() ?? 'Dispositivo desconocido',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Desde ${s['created_at'] ?? '—'}'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Límites vigentes según el nivel KYC.
final kycLimitsProvider = FutureProvider.autoDispose((ref) async {
  // Se recalcula cuando cambia el usuario (p. ej. al aprobarse el KYC).
  ref.watch(authControllerProvider.select((s) => s.user?.kycLevel));
  return ref.read(kycRepositoryProvider).estado();
});

class _Limite extends StatelessWidget {
  const _Limite({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(valor,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    this.activo = false,
    this.trailing,
    this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool activo;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: Radii.brMd,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: (activo ? AppColors.success : AppColors.primary).withValues(alpha: 0.10),
            borderRadius: Radii.brSm,
          ),
          child: Icon(icono, size: 21, color: activo ? AppColors.success : AppColors.primary),
        ),
        title: Text(titulo, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitulo, style: theme.textTheme.bodySmall),
        trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded) : null),
      ),
    );
  }
}
