import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_spacing.dart';

/// Campo de texto estándar de la app: etiqueta externa, icono y
/// soporte de contraseña con botón mostrar/ocultar.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.icono,
    this.esPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.autofillHints,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.prefix,
    this.sufijo,
    this.focusNode,
    this.maxLength,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? icono;
  final bool esPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final Widget? prefix;
  final Widget? sufijo;
  final FocusNode? focusNode;
  final int? maxLength;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _oculto = widget.esPassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: theme.textTheme.labelMedium),
        Gap.h8,
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: _oculto,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          inputFormatters: widget.inputFormatters,
          autofillHints: widget.autofillHints,
          textCapitalization: widget.textCapitalization,
          maxLength: widget.maxLength,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            counterText: '',
            prefixIcon: widget.prefix ?? (widget.icono != null ? Icon(widget.icono, size: 21) : null),
            prefixIconConstraints: widget.prefix != null
                ? const BoxConstraints(minWidth: 0, minHeight: 0)
                : null,
            suffixIcon: widget.esPassword
                ? IconButton(
                    onPressed: () => setState(() => _oculto = !_oculto),
                    icon: Icon(_oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 21),
                    tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  )
                : widget.sufijo,
          ),
        ),
      ],
    );
  }
}
