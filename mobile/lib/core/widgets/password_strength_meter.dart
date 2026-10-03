import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/validators.dart';

/// Medidor visual de fortaleza (misma fórmula que el backend).
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  static const _colores = [
    AppColors.danger,
    AppColors.danger,
    AppColors.warning,
    AppColors.info,
    AppColors.success,
  ];

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox(height: 22);

    final score = Validators.fuerzaPassword(password);
    final color = _colores[score];

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Row(
        children: [
          for (int i = 0; i < 4; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 5,
                decoration: BoxDecoration(
                  color: i < score ? color : AppColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (i < 3) const SizedBox(width: 5),
          ],
          Gap.w8,
          SizedBox(
            width: 70,
            child: Text(
              Validators.etiquetaFuerza(score),
              textAlign: TextAlign.end,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
