import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/numeric_keypad.dart';
import '../application/auth_controller.dart';

/// Creación del PIN de 6 dígitos (dos fases: crear y confirmar).
class PinSetupPage extends ConsumerStatefulWidget {
  const PinSetupPage({super.key});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  String _primero = '';
  String _actual = '';
  bool _confirmando = false;
  bool _error = false;

  void _digito(String d) {
    if (_actual.length >= AppConfig.pinLength) return;
    setState(() {
      _actual += d;
      _error = false;
    });
    if (_actual.length == AppConfig.pinLength) _completo();
  }

  void _borrar() {
    if (_actual.isEmpty) return;
    setState(() => _actual = _actual.substring(0, _actual.length - 1));
  }

  Future<void> _completo() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    if (!_confirmando) {
      setState(() {
        _primero = _actual;
        _actual = '';
        _confirmando = true;
      });
      return;
    }

    if (_actual != _primero) {
      HapticFeedback.heavyImpact();
      setState(() => _error = true);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() {
        _actual = '';
        _primero = '';
        _confirmando = false;
        _error = false;
      });
      Aviso.error(context, 'Los PIN no coinciden. Vuelve a intentarlo.');
      return;
    }

    final ok = await ref.read(authControllerProvider.notifier).configurarPin(_actual);
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(authControllerProvider).error;
      setState(() {
        _actual = '';
        _primero = '';
        _confirmando = false;
      });
      if (error != null) Aviso.error(context, error);
    }
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
              padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
              child: Column(
                children: [
                  Gap.h24,
                  Row(
                    children: [
                      for (int i = 1; i <= 4; i++) ...[
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= 2 ? AppColors.primary : theme.colorScheme.outline,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (i < 4) const SizedBox(width: 6),
                      ],
                      Gap.w12,
                      Text('2/4', style: theme.textTheme.labelSmall),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: Radii.brLg,
                    ),
                    child: const Icon(Icons.pin_outlined, color: AppColors.primary, size: 30),
                  ),
                  Gap.h24,
                  Text(
                    _confirmando ? 'Confirma tu PIN' : 'Crea tu PIN de acceso',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  Gap.h8,
                  Text(
                    _confirmando
                        ? 'Vuelve a escribir los 6 dígitos'
                        : 'Lo usarás para entrar rápido y autorizar envíos',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  Gap.h32,
                  PinDots(
                    length: AppConfig.pinLength,
                    filled: _actual.length,
                    error: _error,
                  ),
                  Gap.h16,
                  SizedBox(
                    height: 20,
                    child: auth.cargando
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            _error ? 'Los PIN no coinciden' : '',
                            style: theme.textTheme.labelMedium?.copyWith(color: AppColors.danger),
                          ),
                  ),
                  const Spacer(),
                  NumericKeypad(
                    enabled: !auth.cargando,
                    onDigit: _digito,
                    onBackspace: _borrar,
                  ),
                  Gap.h16,
                  const InfoBanner(
                    mensaje: 'Evita fechas de nacimiento o secuencias como 123456.',
                    icono: Icons.tips_and_updates_outlined,
                  ),
                  Gap.h24,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
