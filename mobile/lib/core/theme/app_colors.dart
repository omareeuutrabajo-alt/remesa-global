import 'package:flutter/material.dart';

/// Paleta de marca. Un único lugar para los colores: nada de `Color(0x...)`
/// suelto dentro de los widgets.
abstract final class AppColors {
  // Marca
  static const Color navy = Color(0xFF0A1734);
  static const Color navySoft = Color(0xFF14264F);
  static const Color primary = Color(0xFF1757D6);
  static const Color primaryDark = Color(0xFF0F3FA3);
  static const Color primaryLight = Color(0xFF4F85F0);
  static const Color sky = Color(0xFF17B3E8);

  // Dinero / estados
  static const Color success = Color(0xFF0FA968);
  static const Color successSoft = Color(0xFFE6F7F0);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF4E2);
  static const Color danger = Color(0xFFE0394B);
  static const Color dangerSoft = Color(0xFFFDEBEE);
  static const Color info = Color(0xFF2F6BE4);

  // Neutros
  static const Color ink = Color(0xFF0E1726);
  static const Color inkMuted = Color(0xFF5A6474);
  static const Color inkFaint = Color(0xFF98A1B0);
  static const Color line = Color(0xFFE3E7EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF6F8FC);

  // Oscuro
  static const Color darkCanvas = Color(0xFF070F21);
  static const Color darkSurface = Color(0xFF101C35);
  static const Color darkLine = Color(0xFF223250);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, sky],
  );

  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navy, navySoft],
  );
}
