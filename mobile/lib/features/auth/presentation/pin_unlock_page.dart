import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/numeric_keypad.dart';
import '../application/auth_controller.dart';

/// Pantalla de desbloqueo tras inactividad o al reabrir la app.
class PinUnlockPage extends ConsumerStatefulWidget {
  const PinUnlockPage({super.key});

  @override
  ConsumerState<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends ConsumerState<PinUnlockPage> {
  String _pin = '';
  bool _error = false;

  @override
  void initState() {
    super.initState();
    // Si hay biometría activa, se ofrece de inmediato: menos fricción.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authControllerProvider);
      if (auth.biometriaDisponible && auth.biometriaActiva) _biometria();
    });
  }

  void _digito(String d) {
    if (_pin.length >= AppConfig.pinLength) return;
    setState(() {
      _pin += d;
      _error = false;
    });
    if (_pin.length == AppConfig.pinLength) _verificar();
  }

  void _borrar() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verificar() async {
    final ok = await ref.read(authControllerProvider.notifier).desbloquearConPin(_pin);
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() => _error = true);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _pin = '';
        _error = false;
      });
      final error = ref.read(authControllerProvider).error;
      if (error != null && mounted) Aviso.error(context, error);
    }
  }

  Future<void> _biometria() async {
    final ok = await ref.read(authControllerProvider.notifier).entrarConBiometria();
    if (!ok && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final conBiometria = auth.biometriaDisponible && auth.biometriaActiva;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
              child: Column(
                children: [
                  const Spacer(),
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      user?.initials ?? '👤',
                      style: theme.textTheme.titleLarge?.copyWith(color: AppColors.primary),
                    ),
                  ),
                  Gap.h16,
                  Text(
                    user != null ? 'Hola, ${user.firstName}' : 'Bienvenido de vuelta',
                    style: theme.textTheme.headlineSmall,
                  ),
                  Gap.h8,
                  Text('Introduce tu PIN para continuar', style: theme.textTheme.bodyMedium),
                  Gap.h32,
                  PinDots(length: AppConfig.pinLength, filled: _pin.length, error: _error),
                  Gap.h16,
                  SizedBox(
                    height: 20,
                    child: auth.cargando
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            _error ? 'PIN incorrecto' : '',
                            style: theme.textTheme.labelMedium?.copyWith(color: AppColors.danger),
                          ),
                  ),
                  const Spacer(),
                  NumericKeypad(
                    enabled: !auth.cargando,
                    onDigit: _digito,
                    onBackspace: _borrar,
                    onBiometric: conBiometria ? _biometria : null,
                  ),
                  Gap.h8,
                  TextButton(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).cerrarSesion(),
                    child: const Text('Usar otra cuenta'),
                  ),
                  Gap.h16,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
