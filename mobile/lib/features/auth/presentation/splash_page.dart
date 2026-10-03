import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_logo.dart';

/// Pantalla de arranque: se muestra mientras `AuthController.arrancar()`
/// decide si hay sesión, si falta onboarding o si toca pedir el PIN.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final Animation<double> _escala =
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: const Interval(0.3, 1, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Expandido de forma explícita: en el primer frame de web las
        // restricciones llegan sueltas y el degradado se encogía al ancho
        // del texto más largo.
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(gradient: AppColors.navyGradient),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              ScaleTransition(
                scale: _escala,
                child: const AppLogo(size: 104),
              ),
              Gap.h24,
              FadeTransition(
                opacity: _fade,
                child: Column(
                  children: [
                    Text(
                      AppConfig.appName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Gap.h8,
                    Text(
                      AppConfig.appTagline,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FadeTransition(
                opacity: _fade,
                child: const SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                    minHeight: 3,
                  ),
                ),
              ),
              Gap.h48,
            ],
          ),
        ),
      ),
    );
  }
}
