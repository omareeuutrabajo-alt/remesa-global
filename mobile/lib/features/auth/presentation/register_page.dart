import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/countries.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/auth_scaffold.dart';
import '../../../core/widgets/country_field.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/password_strength_meter.dart';
import '../application/auth_controller.dart';

/// Alta de usuario. Al enviarse correctamente el backend emite un OTP
/// y el router redirige automáticamente a la pantalla de verificación.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();
  final _password = TextEditingController();

  Country _pais = Countries.byIso('US');
  bool _acepta = false;
  String _passwordActual = '';

  @override
  void dispose() {
    _nombre.dispose();
    _apellido.dispose();
    _email.dispose();
    _telefono.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_acepta) {
      Aviso.error(context, 'Debes aceptar los términos y condiciones');
      return;
    }

    final telefono = '${_pais.dialCode}${_telefono.text.replaceAll(RegExp(r'\D'), '')}';
    await ref.read(authControllerProvider.notifier).registrar(
          firstName: _nombre.text.trim(),
          lastName: _apellido.text.trim(),
          email: _email.text.trim(),
          phone: telefono,
          countryCode: _pais.iso,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    return AuthScaffold(
      titulo: 'Crea tu cuenta',
      subtitulo: 'Te tomará menos de 2 minutos.',
      paso: 1,
      totalPasos: 4,
      onVolver: () => context.canPop() ? context.pop() : context.go('/login'),
      pie: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('¿Ya tienes cuenta?',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted)),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Inicia sesión'),
          ),
        ],
      ),
      children: [
        if (auth.error != null) ...[
          InfoBanner.error(mensaje: auth.error!),
          Gap.h16,
        ],
        Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Nombre',
                      controller: _nombre,
                      hint: 'María',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.givenName],
                      validator: (v) => Validators.nombre(v, campo: 'El nombre'),
                    ),
                  ),
                  Gap.w12,
                  Expanded(
                    child: AppTextField(
                      label: 'Apellido',
                      controller: _apellido,
                      hint: 'González',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.familyName],
                      validator: (v) => Validators.nombre(v, campo: 'El apellido'),
                    ),
                  ),
                ],
              ),
              Gap.h16,
              AppTextField(
                label: 'Correo electrónico',
                controller: _email,
                hint: 'tucorreo@ejemplo.com',
                icono: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              Gap.h16,
              AppTextField(
                label: 'Teléfono móvil',
                controller: _telefono,
                hint: '412 123 4567',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofillHints: const [AutofillHints.telephoneNumberNational],
                validator: Validators.telefono,
                prefix: CountryDialField(
                  pais: _pais,
                  onChanged: (c) => setState(() => _pais = c),
                ),
              ),
              Gap.h8,
              Text(
                'Te enviaremos un código de verificación por SMS.',
                style: theme.textTheme.labelSmall,
              ),
              Gap.h16,
              AppTextField(
                label: 'Contraseña',
                controller: _password,
                hint: 'Mínimo 8 caracteres',
                icono: Icons.lock_outline_rounded,
                esPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: Validators.password,
                onChanged: (v) => setState(() => _passwordActual = v),
                onSubmitted: (_) => _registrar(),
              ),
              PasswordStrengthMeter(password: _passwordActual),
            ],
          ),
        ),
        Gap.h16,
        _Terminos(
          valor: _acepta,
          onChanged: (v) => setState(() => _acepta = v),
        ),
        Gap.h24,
        AppButton(
          label: 'Continuar',
          cargando: auth.cargando,
          onPressed: _registrar,
        ),
        Gap.h16,
        const SelloSeguridad(texto: 'Tus datos viajan cifrados y nunca se comparten'),
      ],
    );
  }
}

class _Terminos extends StatelessWidget {
  const _Terminos({required this.valor, required this.onChanged});

  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: Radii.brSm,
      onTap: () => onChanged(!valor),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: valor, onChanged: (v) => onChanged(v ?? false)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodySmall,
                    children: const [
                      TextSpan(text: 'Acepto los '),
                      TextSpan(
                        text: 'Términos y Condiciones',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' y la '),
                      TextSpan(
                        text: 'Política de Privacidad',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' del servicio.'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
