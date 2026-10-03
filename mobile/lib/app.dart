import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/feedback.dart';
import 'features/auth/application/auth_controller.dart';

/// Raíz de la aplicación.
///
/// Además de montar tema y router, vigila el ciclo de vida para bloquear
/// la app con PIN tras un periodo de inactividad en segundo plano.
class RemesasApp extends ConsumerStatefulWidget {
  const RemesasApp({super.key});

  @override
  ConsumerState<RemesasApp> createState() => _RemesasAppState();
}

class _RemesasAppState extends ConsumerState<RemesasApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = ref.read(authControllerProvider.notifier);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      auth.registrarActividad();
    } else if (state == AppLifecycleState.resumed) {
      auth.evaluarBloqueoPorInactividad(AppConfig.lockTimeout);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Los mensajes globales (éxito/error) se muestran una sola vez.
    ref.listen(authControllerProvider, (anterior, actual) {
      final messengerContext = router.routerDelegate.navigatorKey.currentContext;
      if (messengerContext == null) return;
      if (actual.mensaje != null && actual.mensaje != anterior?.mensaje) {
        Aviso.exito(messengerContext, actual.mensaje!);
        ref.read(authControllerProvider.notifier).limpiarMensaje();
      }
    });

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        // Bloquea el escalado extremo de fuente para no romper los formularios.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              ref.read(authControllerProvider.notifier).registrarActividad();
            },
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
