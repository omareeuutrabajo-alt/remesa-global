import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias NO sensibles (se permiten en texto plano).
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppPreferences> create() async =>
      AppPreferences(await SharedPreferences.getInstance());

  static const _kOnboarding = 'onboarding.completed';
  static const _kBiometricEnabled = 'security.biometric_enabled';
  static const _kThemeMode = 'ui.theme_mode';

  bool get onboardingCompleted => _prefs.getBool(_kOnboarding) ?? false;
  Future<void> setOnboardingCompleted(bool v) => _prefs.setBool(_kOnboarding, v);

  bool get biometricEnabled => _prefs.getBool(_kBiometricEnabled) ?? false;
  Future<void> setBiometricEnabled(bool v) => _prefs.setBool(_kBiometricEnabled, v);

  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';
  Future<void> setThemeMode(String v) => _prefs.setString(_kThemeMode, v);
}
