import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Campo de código de un solo uso.
///
/// • Avanza y retrocede solo entre casillas.
/// • Acepta pegar el código completo (SMS autofill incluido).
/// • Sacude y pinta de rojo cuando el código es incorrecto.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.length,
    required this.onCompleted,
    this.onChanged,
    this.error = false,
    this.enabled = true,
    this.autofocus = true,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool error;
  final bool enabled;
  final bool autofocus;

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> with SingleTickerProviderStateMixin {
  late final List<TextEditingController> _controllers =
      List.generate(widget.length, (_) => TextEditingController());
  late final List<FocusNode> _nodes = List.generate(widget.length, (_) => FocusNode());
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  String get valor => _controllers.map((c) => c.text).join();

  @override
  void didUpdateWidget(covariant OtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error && !oldWidget.error) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    _shake.dispose();
    super.dispose();
  }

  /// Limpia las casillas y vuelve al inicio (tras un código inválido).
  void limpiar() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) _nodes.first.requestFocus();
    widget.onChanged?.call('');
  }

  void _alEscribir(int index, String texto) {
    // Pegado de código completo.
    if (texto.length > 1) {
      final digitos = texto.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < widget.length; i++) {
        _controllers[i].text = i < digitos.length ? digitos[i] : '';
      }
      final ultimo = digitos.length.clamp(0, widget.length - 1);
      _nodes[ultimo].requestFocus();
      _notificar();
      return;
    }

    if (texto.isNotEmpty && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    }
    _notificar();
  }

  void _notificar() {
    final code = valor;
    widget.onChanged?.call(code);
    if (code.length == widget.length) {
      FocusScope.of(context).unfocus();
      widget.onCompleted(code);
    }
  }

  void _alBorrar(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _nodes[index - 1].requestFocus();
      _notificar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = t == 0 ? 0.0 : 10 * (1 - t) * (t * 10 % 2 < 1 ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(widget.length, (i) => _casilla(context, i)),
      ),
    );
  }

  Widget _casilla(BuildContext context, int i) {
    final lleno = _controllers[i].text.isNotEmpty;
    final enfocado = _nodes[i].hasFocus;
    final color = widget.error
        ? AppColors.danger
        : enfocado
            ? AppColors.primary
            : lleno
                ? AppColors.primaryLight
                : Theme.of(context).colorScheme.outline;

    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AspectRatio(
          aspectRatio: 0.82,
          child: KeyboardListener(
            focusNode: FocusNode(skipTraversal: true),
            onKeyEvent: (event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace) {
                _alBorrar(i);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: widget.error
                    ? AppColors.dangerSoft
                    : Theme.of(context).colorScheme.surface,
                borderRadius: Radii.brMd,
                border: Border.all(color: color, width: enfocado || lleno ? 1.8 : 1.2),
              ),
              child: Center(
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _nodes[i],
                  enabled: widget.enabled,
                  autofocus: widget.autofocus && i == 0,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: i == 0 ? widget.length : 1,
                  showCursor: false,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: widget.error ? AppColors.danger : null,
                      ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => _alEscribir(i, v),
                  onTap: () => setState(() {}),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
