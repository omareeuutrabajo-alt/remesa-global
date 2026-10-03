import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/feedback.dart';
import '../application/auth_controller.dart';

/// Paso 1 de la recuperación: pedir el correo y disparar el OTP.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(authRepositoryProvider).lastEmail.then((e) {
      if (e != null && mounted) _email.text = e;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .solicitarRecuperacion(_email.text.trim());
    if (!mounted) return;
    if (!ok) {
      final estado = ref.read(authControllerProvider);
      if (estado.mensaje != null) Aviso.info(context, estado.mensaje!);
      if (estado.error != null) Aviso.error(context, estado.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return AuthScaffold(
      titulo: '¿Olvidaste tu contraseña?',
      subtitulo: 'Te enviaremos un código para crear una nueva.',
      icono: Icons.lock_reset_rounded,
      onVolver: () => context.canPop() ? context.pop() : context.go('/login'),
      children: [
        if (auth.error != null) ...[
          InfoBanner.error(mensaje: auth.error!),
          Gap.h16,
        ],
        Form(
          key: _formKey,
          child: AppTextField(
            label: 'Correo electrónico',
            controller: _email,
            hint: 'tucorreo@ejemplo.com',
            icono: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            validator: Validators.email,
            onSubmitted: (_) => _enviar(),
          ),
        ),
        Gap.h16,
        const InfoBanner(
          mensaje: 'Por seguridad, siempre respondemos lo mismo exista o no la cuenta.',
          icono: Icons.shield_outlined,
        ),
        Gap.h24,
        AppButton(
          label: 'Enviar código',
          cargando: auth.cargando,
          onPressed: _enviar,
        ),
        Gap.h8,
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Volver al inicio de sesión'),
        ),
      ],
    );
  }
}
