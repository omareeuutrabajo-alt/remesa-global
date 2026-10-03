import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/feedback.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

/// Inicio de sesión: correo + contraseña, con acceso biométrico si el
/// usuario ya lo activó en este dispositivo.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  String _etiquetaBiometria = 'Biometría';

  @override
  void initState() {
    super.initState();
    _precargar();
  }

  Future<void> _precargar() async {
    final repo = ref.read(authRepositoryProvider);
    final email = await repo.lastEmail;
    final etiqueta = await ref.read(biometricServiceProvider).etiqueta;
    if (!mounted) return;
    setState(() {
      if (email != null) _email.text = email;
      _etiquetaBiometria = etiqueta;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).iniciarSesion(
          email: _email.text.trim(),
          password: _password.text,
        );
  }

  Future<void> _entrarConBiometria() async {
    final ok = await ref.read(authControllerProvider.notifier).entrarConBiometria();
    if (!ok && mounted) {
      final error = ref.read(authControllerProvider).error;
      if (error != null) Aviso.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final mostrarBiometria = auth.biometriaDisponible && auth.biometriaActiva;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xxl, Gap.xl, Gap.xl),
              children: [
                const Center(child: AppLogo(size: 66)),
                Gap.h24,
                Text('Hola de nuevo 👋', style: theme.textTheme.headlineMedium),
                Gap.h8,
                Text(
                  'Entra a tu cuenta para enviar dinero a tus seres queridos.',
                  style: theme.textTheme.bodyMedium,
                ),
                Gap.h32,

                if (auth.error != null) ...[
                  InfoBanner.error(mensaje: auth.error!),
                  Gap.h16,
                ],

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        label: 'Correo electrónico',
                        controller: _email,
                        hint: 'tucorreo@ejemplo.com',
                        icono: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.email,
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                      ),
                      Gap.h16,
                      AppTextField(
                        label: 'Contraseña',
                        controller: _password,
                        focusNode: _passwordFocus,
                        hint: '••••••••',
                        icono: Icons.lock_outline_rounded,
                        esPassword: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        validator: (v) => Validators.requerido(v, campo: 'La contraseña'),
                        onSubmitted: (_) => _entrar(),
                      ),
                    ],
                  ),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/recuperar'),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                Gap.h8,

                AppButton(
                  label: 'Iniciar sesión',
                  cargando: auth.cargando,
                  onPressed: _entrar,
                ),

                if (mostrarBiometria) ...[
                  Gap.h16,
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                        child: Text('o', style: theme.textTheme.labelSmall),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  Gap.h16,
                  AppButton(
                    label: 'Entrar con $_etiquetaBiometria',
                    variante: BotonVariante.secundario,
                    icono: Icons.fingerprint_rounded,
                    onPressed: auth.cargando ? null : _entrarConBiometria,
                  ),
                ],

                Gap.h32,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('¿Aún no tienes cuenta?', style: theme.textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => context.push('/registro'),
                      child: const Text('Regístrate'),
                    ),
                  ],
                ),
                Gap.h16,
                const SelloSeguridad(),
                Gap.h8,
                _AvisoEntornoPruebas(cargando: auth.cargando),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Atajo visible solo en desarrollo para rellenar credenciales de demo.
class _AvisoEntornoPruebas extends ConsumerWidget {
  const _AvisoEntornoPruebas({required this.cargando});

  final bool cargando;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.status != AuthStatus.invitado) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Gap.md),
      child: Text(
        'Entorno de demostración · el código SMS se muestra en pantalla',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.inkFaint),
      ),
    );
  }
}
