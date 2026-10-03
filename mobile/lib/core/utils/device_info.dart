import 'dart:math';

import 'package:flutter/foundation.dart';

import '../storage/secure_storage.dart';

/// Identidad estable del dispositivo.
///
/// Se genera una sola vez y se guarda cifrada: el backend la usa para
/// marcar el dispositivo como de confianza y para anclar la biometría.
class DeviceInfo {
  DeviceInfo(this._storage);

  final SecureStorage _storage;

  Future<String> deviceId() async {
    final existing = await _storage.deviceId;
    if (existing != null && existing.length >= 8) return existing;

    final rnd = Random.secure();
    final id = 'dev-${List.generate(16, (_) => rnd.nextInt(16).toRadixString(16)).join()}';
    await _storage.saveDeviceId(id);
    return id;
  }

  String get platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => 'web',
    };
  }

  String get deviceName {
    if (kIsWeb) return 'Navegador web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Dispositivo Android',
      TargetPlatform.iOS => 'iPhone',
      TargetPlatform.macOS => 'Mac',
      TargetPlatform.windows => 'Windows',
      _ => 'Dispositivo',
    };
  }
}
