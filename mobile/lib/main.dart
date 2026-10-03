import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/app_preferences.dart';
import 'features/auth/application/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Árbol de accesibilidad siempre activo. Se usa para auditorías y para las
  // pruebas automatizadas de interfaz:
  //   flutter build web --dart-define=ENABLE_SEMANTICS=true
  if (const bool.fromEnvironment('ENABLE_SEMANTICS')) {
    SemanticsBinding.instance.ensureSemantics();
  }

  // La app de remesas es vertical: evita layouts rotos en el flujo de KYC.
  // En web no aplica (y el bloqueo de orientación deja la vista con un
  // tamaño provisional durante el primer frame).
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Preferencias cargadas antes del primer frame: el router las necesita
  // de forma síncrona para decidir si mostrar el onboarding.
  final prefs = await AppPreferences.create();

  runApp(
    ProviderScope(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
      child: const RemesasApp(),
    ),
  );
}
