import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/biometric_setup_page.dart';
import '../../features/auth/presentation/forgot_password_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/onboarding_page.dart';
import '../../features/auth/presentation/otp_page.dart';
import '../../features/auth/presentation/pin_setup_page.dart';
import '../../features/auth/presentation/pin_unlock_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/reset_password_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/kyc/presentation/kyc_flow_page.dart';
import '../../features/kyc/presentation/kyc_pending_page.dart';

abstract final class Rutas {
  static const splash = '/';
  static const onboarding = '/bienvenida';
  static const login = '/login';
  static const registro = '/registro';
  static const otp = '/verificar';
  static const recuperar = '/recuperar';
  static const nuevaPassword = '/nueva-password';
  static const pinSetup = '/pin';
  static const biometria = '/biometria';
  static const desbloquear = '/desbloquear';
  static const kyc = '/kyc';
  static const kycPendiente = '/kyc/revision';
  static const home = '/inicio';

  /// Pantallas accesibles sin sesión.
  static const publicas = {login, registro, recuperar, onboarding, otp, nuevaPassword};
}

/// Router con guardas: la navegación del onboarding la decide el
/// estado de sesión, no los botones. Así es imposible saltarse un paso.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Rutas.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(path: Rutas.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: Rutas.onboarding, builder: (_, _) => const OnboardingPage()),
      GoRoute(path: Rutas.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: Rutas.registro, builder: (_, _) => const RegisterPage()),
      GoRoute(path: Rutas.otp, builder: (_, _) => const OtpPage()),
      GoRoute(path: Rutas.recuperar, builder: (_, _) => const ForgotPasswordPage()),
      GoRoute(path: Rutas.nuevaPassword, builder: (_, _) => const ResetPasswordPage()),
      GoRoute(path: Rutas.pinSetup, builder: (_, _) => const PinSetupPage()),
      GoRoute(
        path: Rutas.biometria,
        builder: (context, _) => BiometricSetupPage(
          onContinuar: () => context.go(Rutas.home),
        ),
      ),
      GoRoute(path: Rutas.desbloquear, builder: (_, _) => const PinUnlockPage()),
      GoRoute(path: Rutas.kyc, builder: (_, _) => const KycFlowPage()),
      GoRoute(path: Rutas.kycPendiente, builder: (_, _) => const KycPendingPage()),
      GoRoute(path: Rutas.home, builder: (_, _) => const HomePage()),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final prefs = ref.read(preferencesProvider);
      final yendoA = state.matchedLocation;

      // 1. Aún comprobando la sesión guardada.
      if (auth.status == AuthStatus.desconocido) {
        return yendoA == Rutas.splash ? null : Rutas.splash;
      }

      // 2. Falta el segundo factor.
      if (auth.status == AuthStatus.esperandoOtp) {
        return yendoA == Rutas.otp ? null : Rutas.otp;
      }

      // 3. Sin sesión.
      if (auth.status == AuthStatus.invitado) {
        if (auth.nextStep == 'reset_password' && auth.resetToken != null) {
          return yendoA == Rutas.nuevaPassword ? null : Rutas.nuevaPassword;
        }
        if (!prefs.onboardingCompleted && yendoA == Rutas.splash) {
          return Rutas.onboarding;
        }
        if (Rutas.publicas.contains(yendoA)) return null;
        return Rutas.login;
      }

      // 4. Sesión válida pero bloqueada por inactividad.
      if (auth.status == AuthStatus.bloqueado) {
        return yendoA == Rutas.desbloquear ? null : Rutas.desbloquear;
      }

      // 5. Autenticado: el backend dicta el siguiente paso del onboarding.
      final destino = switch (auth.nextStep) {
        'verify_otp' => Rutas.otp,
        'pin_setup' => Rutas.pinSetup,
        'kyc' => Rutas.kyc,
        'kyc_pending' => Rutas.kycPendiente,
        _ => Rutas.home,
      };

      // La pantalla de biometría es opcional: no se fuerza ni se bloquea.
      if (yendoA == Rutas.biometria && destino == Rutas.home) return null;

      return yendoA == destino ? null : destino;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.explore_off_outlined, size: 56),
              const SizedBox(height: 16),
              Text('No encontramos esa pantalla',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(state.uri.toString(), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(Rutas.splash),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
});
