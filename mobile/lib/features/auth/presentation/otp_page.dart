import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/otp_input.dart';
import '../application/auth_controller.dart';

/// Verificación en dos pasos. Sirve para los tres propósitos del backend:
/// alta de cuenta, inicio de sesión en dispositivo nuevo y recuperación.
class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _otpKey = GlobalKey<OtpInputState>();
  String _codigo = '';
  bool _error = false;
  int _segundos = AppConfig.otpResendSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciarCuenta();
  }

  void _iniciarCuenta() {
    _timer?.cancel();
    setState(() => _segundos = AppConfig.otpResendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundos <= 1) {
        t.cancel();
        if (mounted) setState(() => _segundos = 0);
      } else if (mounted) {
        setState(() => _segundos--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verificar() async {
    if (_codigo.length != AppConfig.otpLength) return;
    FocusScope.of(context).unfocus();
    final ok = await ref.read(authControllerProvider.notifier).verificarOtp(_codigo);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = true);
      HapticFeedback.heavyImpact();
      _otpKey.currentState?.limpiar();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) setState(() => _error = false);
    }
  }

  Future<void> _reenviar() async {
    final ok = await ref.read(authControllerProvider.notifier).reenviarOtp();
    if (!mounted) return;
    if (ok) {
      _iniciarCuenta();
      _otpKey.currentState?.limpiar();
      Aviso.exito(context, 'Te enviamos un código nuevo');
    } else {
      final error = ref.read(authControllerProvider).error;
      if (error != null) Aviso.error(context, error);
    }
  }

  String _titulo(String purpose) => switch (purpose) {
        'register' => 'Verifica tu número',
        'password_reset' => 'Revisa tu correo',
        _ => 'Confirma que eres tú',
      };

  String _descripcion(String purpose, String destino) => switch (purpose) {
        'register' => 'Enviamos un código de 6 dígitos por SMS a $destino',
        'password_reset' => 'Enviamos un código de 6 dígitos a $destino',
        _ => 'Detectamos un inicio de sesión desde un dispositivo nuevo. Enviamos un código a $destino',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final challenge = auth.challenge;

    if (challenge == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            ref.read(authControllerProvider.notifier).volverAlLogin();
            context.go('/login');
          },
        ),
        title: const Text('Verificación'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.sm, Gap.xl, Gap.xl),
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: Radii.brLg,
                  ),
                  child: Icon(
                    challenge.purpose == 'password_reset'
                        ? Icons.mark_email_unread_outlined
                        : Icons.sms_outlined,
                    color: AppColors.primary,
                    size: 34,
                  ),
                ),
                Gap.h24,
                Text(_titulo(challenge.purpose), style: theme.textTheme.headlineMedium),
                Gap.h8,
                Text(
                  _descripcion(challenge.purpose, challenge.destino),
                  style: theme.textTheme.bodyMedium,
                ),
                Gap.h32,

                OtpInput(
                  key: _otpKey,
                  length: AppConfig.otpLength,
                  error: _error,
                  enabled: !auth.cargando,
                  onChanged: (v) => setState(() => _codigo = v),
                  onCompleted: (_) => _verificar(),
                ),

                if (auth.error != null) ...[
                  Gap.h16,
                  InfoBanner.error(mensaje: auth.error!),
                ],

                // Ayuda de entorno de pruebas: el backend devuelve el código.
                if (challenge.devCode != null) ...[
                  Gap.h16,
                  _CodigoDemo(
                    codigo: challenge.devCode!,
                    onUsar: () {
                      setState(() => _codigo = challenge.devCode!);
                      _verificar();
                    },
                  ),
                ],

                Gap.h24,
                AppButton(
                  label: 'Verificar código',
                  cargando: auth.cargando,
                  onPressed: _codigo.length == AppConfig.otpLength ? _verificar : null,
                ),
                Gap.h16,
                Center(
                  child: _segundos > 0
                      ? Text(
                          'Puedes pedir otro código en 00:${_segundos.toString().padLeft(2, '0')}',
                          style: theme.textTheme.labelMedium,
                        )
                      : TextButton.icon(
                          onPressed: auth.cargando ? null : _reenviar,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Reenviar código'),
                        ),
                ),
                Gap.h24,
                const SelloSeguridad(texto: 'Nunca compartas este código, ni con nuestro soporte'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CodigoDemo extends StatelessWidget {
  const _CodigoDemo({required this.codigo, required this.onUsar});

  final String codigo;
  final VoidCallback onUsar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: Radii.brMd,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: AppColors.warning, size: 20),
          Gap.w12,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Modo demostración',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        )),
                Text(
                  'Tu código SMS es $codigo',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onUsar, child: const Text('Usar')),
        ],
      ),
    );
  }
}
