import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/password_strength_meter.dart';
import '../application/auth_controller.dart';

/// Paso 2 de la recuperación: nueva contraseña con el token de un solo uso.
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();
  String _actual = '';

  @override
  void dispose() {
    _password.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).restablecerPassword(_password.text);
    if (!mounted) return;
    if (ok) {
      Aviso.exito(context, 'Contraseña actualizada. Inicia sesión.');
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return AuthScaffold(
      titulo: 'Crea una contraseña nueva',
      subtitulo: 'Se cerrarán todas las sesiones abiertas en otros dispositivos.',
      icono: Icons.password_rounded,
      mostrarVolver: false,
      children: [
        if (auth.error != null) ...[
          InfoBanner.error(mensaje: auth.error!),
          Gap.h16,
        ],
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                label: 'Nueva contraseña',
                controller: _password,
                hint: 'Mínimo 8 caracteres',
                icono: Icons.lock_outline_rounded,
                esPassword: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
                onChanged: (v) => setState(() => _actual = v),
              ),
              PasswordStrengthMeter(password: _actual),
              Gap.h16,
              AppTextField(
                label: 'Repite la contraseña',
                controller: _confirmacion,
                hint: 'Vuelve a escribirla',
                icono: Icons.lock_person_outlined,
                esPassword: true,
                textInputAction: TextInputAction.done,
                validator: (v) => Validators.confirmacion(v, _password.text),
                onSubmitted: (_) => _guardar(),
              ),
            ],
          ),
        ),
        Gap.h24,
        AppButton(
          label: 'Guardar contraseña',
          cargando: auth.cargando,
          onPressed: _guardar,
        ),
      ],
    );
  }
}
