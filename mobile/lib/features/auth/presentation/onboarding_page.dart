import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_logo.dart';
import '../application/auth_controller.dart';

class _Slide {
  const _Slide(this.icono, this.titulo, this.texto, this.color);
  final IconData icono;
  final String titulo;
  final String texto;
  final Color color;
}

const _slides = [
  _Slide(Icons.bolt_rounded, 'Llega en minutos',
      'Tu familia recibe el dinero el mismo día, con seguimiento en tiempo real de cada envío.',
      AppColors.primary),
  _Slide(Icons.savings_outlined, 'Tarifas transparentes',
      'Ves la comisión y la tasa de cambio antes de confirmar. Sin cargos ocultos, nunca.',
      AppColors.success),
  _Slide(Icons.verified_user_outlined, 'Seguridad bancaria',
      'Verificación en dos pasos, PIN y biometría. Tu dinero y tus datos siempre protegidos.',
      AppColors.sky),
];

/// Presentación inicial. Solo se muestra una vez (se guarda en preferencias).
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  int _indice = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _terminar(String destino) async {
    await ref.read(preferencesProvider).setOnboardingCompleted(true);
    if (mounted) context.go(destino);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esUltima = _indice == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth + 60),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.md, Gap.lg, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppWordmark(size: 30),
                      TextButton(
                        onPressed: () => _terminar('/login'),
                        child: const Text('Omitir'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _indice = i),
                    itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 7,
                      width: i == _indice ? 26 : 7,
                      decoration: BoxDecoration(
                        color: i == _indice ? AppColors.primary : theme.colorScheme.outline,
                        borderRadius: Radii.brSm,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Gap.xl),
                  child: Column(
                    children: [
                      AppButton(
                        label: esUltima ? 'Crear mi cuenta' : 'Siguiente',
                        icono: esUltima ? Icons.person_add_alt_1_rounded : null,
                        onPressed: () {
                          if (esUltima) {
                            _terminar('/registro');
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                      ),
                      Gap.h12,
                      TextButton(
                        onPressed: () => _terminar('/login'),
                        child: const Text('Ya tengo una cuenta'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  slide.color.withValues(alpha: 0.16),
                  slide.color.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Icon(slide.icono, size: 84, color: slide.color),
          ),
          Gap.h48,
          Text(slide.titulo, textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
          Gap.h16,
          Text(slide.texto, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}
