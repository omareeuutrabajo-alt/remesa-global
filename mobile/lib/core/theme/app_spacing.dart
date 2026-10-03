import 'package:flutter/widgets.dart';

/// Escala de espaciado de 4 pt y radios estándar.
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const Widget h4 = SizedBox(height: xs);
  static const Widget h8 = SizedBox(height: sm);
  static const Widget h12 = SizedBox(height: md);
  static const Widget h16 = SizedBox(height: lg);
  static const Widget h24 = SizedBox(height: xl);
  static const Widget h32 = SizedBox(height: xxl);
  static const Widget h48 = SizedBox(height: xxxl);

  static const Widget w8 = SizedBox(width: sm);
  static const Widget w12 = SizedBox(width: md);
  static const Widget w16 = SizedBox(width: lg);
}

abstract final class Radii {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
}

/// Ancho máximo del contenido: evita formularios deformados en tablet/web.
const double kMaxContentWidth = 440;
