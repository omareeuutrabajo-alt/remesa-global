import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/feedback.dart';
import '../../auth/application/auth_controller.dart';
import '../data/kyc_repository.dart';

final kycRepositoryProvider =
    Provider<KycRepository>((ref) => KycRepository(ref.watch(apiClientProvider)));

/// Tipos de documento aceptados por compliance.
enum TipoDocumento {
  nationalId('national_id', 'Cédula / DNI', Icons.badge_outlined, true),
  passport('passport', 'Pasaporte', Icons.book_outlined, false),
  driversLicense('drivers_license', 'Licencia de conducir', Icons.directions_car_outlined, true);

  const TipoDocumento(this.valor, this.etiqueta, this.icono, this.requiereReverso);

  final String valor;
  final String etiqueta;
  final IconData icono;
  final bool requiereReverso;
}

/// Flujo de verificación de identidad en 3 pasos:
/// datos del documento → capturas → selfie y envío.
class KycFlowPage extends ConsumerStatefulWidget {
  const KycFlowPage({super.key});

  @override
  ConsumerState<KycFlowPage> createState() => _KycFlowPageState();
}

class _KycFlowPageState extends ConsumerState<KycFlowPage> {
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _numero = TextEditingController();
  final _nacimiento = TextEditingController();

  int _paso = 0;
  TipoDocumento _tipo = TipoDocumento.nationalId;
  XFile? _frente;
  XFile? _reverso;
  XFile? _selfie;
  bool _enviando = false;

  @override
  void dispose() {
    _numero.dispose();
    _nacimiento.dispose();
    super.dispose();
  }

  Future<void> _capturar(String destino) async {
    try {
      // En navegador no hay cámara nativa disponible para image_picker:
      // allí se abre el selector de ficheros para poder probar el flujo.
      final usaCamara = destino == 'selfie' && !kIsWeb;
      final foto = await _picker.pickImage(
        source: usaCamara ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1800,
        preferredCameraDevice:
            usaCamara ? CameraDevice.front : CameraDevice.rear,
      );
      if (foto == null) return;
      setState(() {
        switch (destino) {
          case 'frente':
            _frente = foto;
          case 'reverso':
            _reverso = foto;
          case 'selfie':
            _selfie = foto;
        }
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) Aviso.error(context, 'No se pudo acceder a la cámara: $e');
    }
  }

  bool get _documentoListo =>
      _frente != null && (!_tipo.requiereReverso || _reverso != null);

  Future<void> _enviar() async {
    if (_selfie == null || !_documentoListo) return;
    setState(() => _enviando = true);
    try {
      await ref.read(kycRepositoryProvider).enviar(
            documentType: _tipo.valor,
            documentNumber: _numero.text.trim(),
            birthDate: _nacimiento.text.trim().isEmpty ? null : _nacimiento.text.trim(),
            documentFront: _frente!,
            documentBack: _tipo.requiereReverso ? _reverso : null,
            selfie: _selfie!,
          );
      await ref.read(authControllerProvider.notifier).refrescarUsuario();
      if (mounted) Aviso.exito(context, 'Documentos enviados. Te avisaremos al terminar.');
    } on ApiException catch (e) {
      if (mounted) Aviso.error(context, e.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifica tu identidad'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).cerrarSesion(),
            child: const Text('Salir'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth + 40),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.xl, vertical: Gap.sm),
                  child: Row(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= _paso ? AppColors.primary : theme.colorScheme.outline,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (i < 2) const SizedBox(width: 6),
                      ],
                      Gap.w12,
                      Text('${_paso + 1}/3', style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _paso,
                    children: [_pasoDatos(), _pasoDocumento(), _pasoSelfie()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ─────────────── Paso 1: datos ─────────────── */

  Widget _pasoDatos() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(Gap.xl),
      children: [
        Text('¿Con qué documento te identificas?', style: theme.textTheme.headlineSmall),
        Gap.h8,
        Text(
          'Lo exige la normativa de prevención de lavado de dinero. '
          'Solo lo pediremos una vez.',
          style: theme.textTheme.bodyMedium,
        ),
        Gap.h24,
        for (final tipo in TipoDocumento.values) ...[
          _OpcionDocumento(
            tipo: tipo,
            seleccionado: _tipo == tipo,
            onTap: () => setState(() {
              _tipo = tipo;
              _reverso = null;
            }),
          ),
          Gap.h12,
        ],
        Gap.h8,
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                label: 'Número de documento',
                controller: _numero,
                hint: 'V-12.345.678',
                icono: Icons.numbers_rounded,
                textCapitalization: TextCapitalization.characters,
                validator: Validators.documento,
              ),
              Gap.h16,
              AppTextField(
                label: 'Fecha de nacimiento (opcional)',
                controller: _nacimiento,
                hint: 'AAAA-MM-DD',
                icono: Icons.cake_outlined,
                keyboardType: TextInputType.datetime,
              ),
            ],
          ),
        ),
        Gap.h24,
        AppButton(
          label: 'Continuar',
          onPressed: () {
            if (_formKey.currentState!.validate()) setState(() => _paso = 1);
          },
        ),
      ],
    );
  }

  /* ─────────────── Paso 2: capturas ─────────────── */

  Widget _pasoDocumento() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(Gap.xl),
      children: [
        Text('Fotografía tu ${_tipo.etiqueta.toLowerCase()}', style: theme.textTheme.headlineSmall),
        Gap.h8,
        Text('Asegúrate de que se lean todos los datos y no haya reflejos.',
            style: theme.textTheme.bodyMedium),
        Gap.h24,
        _ZonaCaptura(
          titulo: 'Frente del documento',
          archivo: _frente,
          icono: Icons.credit_card_outlined,
          onTap: () => _capturar('frente'),
        ),
        if (_tipo.requiereReverso) ...[
          Gap.h16,
          _ZonaCaptura(
            titulo: 'Reverso del documento',
            archivo: _reverso,
            icono: Icons.flip_to_back_rounded,
            onTap: () => _capturar('reverso'),
          ),
        ],
        Gap.h24,
        const InfoBanner(
          mensaje: 'Formatos JPG, PNG o WEBP de hasta 8 MB. '
              'Las imágenes se cifran en tránsito y se guardan en almacenamiento restringido.',
          icono: Icons.lock_outline_rounded,
        ),
        Gap.h24,
        AppButton(
          label: 'Continuar',
          onPressed: _documentoListo ? () => setState(() => _paso = 2) : null,
        ),
        Gap.h8,
        TextButton(onPressed: () => setState(() => _paso = 0), child: const Text('Volver')),
      ],
    );
  }

  /* ─────────────── Paso 3: selfie ─────────────── */

  Widget _pasoSelfie() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(Gap.xl),
      children: [
        Text('Tómate una selfie', style: theme.textTheme.headlineSmall),
        Gap.h8,
        Text('Compararemos tu rostro con la foto del documento. Busca buena luz y mira al frente.',
            style: theme.textTheme.bodyMedium),
        Gap.h24,
        Center(
          child: GestureDetector(
            onTap: () => _capturar('selfie'),
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selfie != null
                    ? AppColors.successSoft
                    : AppColors.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: _selfie != null ? AppColors.success : AppColors.primary,
                  width: 2.5,
                ),
              ),
              child: Icon(
                _selfie != null ? Icons.check_rounded : Icons.camera_alt_outlined,
                size: 64,
                color: _selfie != null ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
        ),
        Gap.h16,
        Center(
          child: Text(
            _selfie != null
                ? 'Selfie capturada ✓'
                : (kIsWeb ? 'Toca el círculo para subir tu selfie' : 'Toca el círculo para abrir la cámara'),
            style: theme.textTheme.labelMedium,
          ),
        ),
        Gap.h24,
        const InfoBanner(
          mensaje: 'No uses gafas de sol ni gorra. El proceso dura unos segundos.',
          icono: Icons.face_retouching_natural_outlined,
        ),
        Gap.h24,
        AppButton(
          label: 'Enviar verificación',
          cargando: _enviando,
          onPressed: _selfie != null ? _enviar : null,
        ),
        Gap.h8,
        TextButton(onPressed: () => setState(() => _paso = 1), child: const Text('Volver')),
      ],
    );
  }
}

class _OpcionDocumento extends StatelessWidget {
  const _OpcionDocumento({required this.tipo, required this.seleccionado, required this.onTap});

  final TipoDocumento tipo;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: Radii.brMd,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.primary.withValues(alpha: 0.06) : theme.colorScheme.surface,
          borderRadius: Radii.brMd,
          border: Border.all(
            color: seleccionado ? AppColors.primary : theme.colorScheme.outline,
            width: seleccionado ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(tipo.icono, color: seleccionado ? AppColors.primary : theme.colorScheme.onSurfaceVariant),
            Gap.w16,
            Expanded(child: Text(tipo.etiqueta, style: theme.textTheme.titleMedium)),
            Icon(
              seleccionado ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: seleccionado ? AppColors.primary : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _ZonaCaptura extends StatelessWidget {
  const _ZonaCaptura({
    required this.titulo,
    required this.archivo,
    required this.icono,
    required this.onTap,
  });

  final String titulo;
  final XFile? archivo;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listo = archivo != null;
    return InkWell(
      borderRadius: Radii.brMd,
      onTap: onTap,
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          color: listo ? AppColors.successSoft : theme.colorScheme.surface,
          borderRadius: Radii.brMd,
          border: Border.all(
            color: listo ? AppColors.success : theme.colorScheme.outline,
            width: listo ? 1.6 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Gap.w16,
            Icon(listo ? Icons.check_circle_rounded : icono,
                size: 34, color: listo ? AppColors.success : AppColors.inkFaint),
            Gap.w16,
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: theme.textTheme.titleMedium),
                  Gap.h4,
                  Text(
                    listo ? 'Imagen cargada · toca para cambiar' : 'Toca para capturar o subir',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Gap.w16,
          ],
        ),
      ),
    );
  }
}
