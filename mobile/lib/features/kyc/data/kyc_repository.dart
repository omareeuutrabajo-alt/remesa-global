import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/models/auth_models.dart';

/// Acceso a los endpoints de verificación de identidad.
class KycRepository {
  KycRepository(this._api);

  final ApiClient _api;

  Future<KycStatus> estado() async {
    final data = await _api.get('/kyc/status');
    return KycStatus.fromJson(data);
  }

  /// Envía el expediente. `documentBack` es opcional para pasaportes.
  Future<KycStatus> enviar({
    required String documentType,
    required String documentNumber,
    String? birthDate,
    String? address,
    required XFile documentFront,
    XFile? documentBack,
    required XFile selfie,
  }) async {
    Future<MultipartFile> parte(XFile f) async => kIsWeb
        ? MultipartFile.fromBytes(await f.readAsBytes(), filename: f.name)
        : MultipartFile.fromFile(f.path, filename: f.name);

    final form = FormData.fromMap({
      'documentType': documentType,
      'documentNumber': documentNumber,
      'birthDate': ?birthDate,
      if (address != null && address.isNotEmpty) 'address': address,
      'documentFront': await parte(documentFront),
      'selfie': await parte(selfie),
    });

    if (documentBack != null) {
      form.files.add(MapEntry('documentBack', await parte(documentBack)));
    }

    await _api.postMultipart('/kyc/submit', form);
    return estado();
  }
}
