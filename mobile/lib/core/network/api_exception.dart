import 'package:dio/dio.dart';

/// Error de API ya traducido a lenguaje de dominio.
/// La UI solo necesita `message`; la lógica puede ramificar por `code`.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  final String code;
  final String message;
  final int? statusCode;
  final dynamic details;

  bool get isNetwork => code == 'NETWORK_ERROR' || code == 'TIMEOUT';
  bool get isUnauthorized => statusCode == 401;

  /// Intentos restantes que devuelve el backend en login / OTP / PIN.
  int? get attemptsLeft {
    if (details is Map && details['attemptsLeft'] is int) {
      return details['attemptsLeft'] as int;
    }
    return null;
  }

  /// Errores de validación campo→mensaje para pintarlos en el formulario.
  Map<String, String> get fieldErrors {
    if (details is! List) return const {};
    final out = <String, String>{};
    for (final item in details as List) {
      if (item is Map && item['field'] is String && item['message'] is String) {
        out[item['field'] as String] = item['message'] as String;
      }
    }
    return out;
  }

  /// Traduce cualquier [DioException] en algo presentable al usuario.
  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          code: 'TIMEOUT',
          message: 'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return const ApiException(
          code: 'NETWORK_ERROR',
          message: 'Sin conexión con el servidor. Revisa tu internet.',
        );
      case DioExceptionType.cancel:
        return const ApiException(code: 'CANCELLED', message: 'Solicitud cancelada.');
      case DioExceptionType.badCertificate:
        return const ApiException(
          code: 'BAD_CERTIFICATE',
          message: 'No se pudo establecer una conexión segura.',
        );
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        if (data is Map && data['error'] is Map) {
          final err = data['error'] as Map;
          return ApiException(
            code: (err['code'] ?? 'UNKNOWN').toString(),
            message: (err['message'] ?? 'Ocurrió un error inesperado.').toString(),
            statusCode: e.response?.statusCode,
            details: err['details'],
          );
        }
        return ApiException(
          code: 'HTTP_${e.response?.statusCode ?? 0}',
          message: 'Ocurrió un error inesperado. Inténtalo más tarde.',
          statusCode: e.response?.statusCode,
        );
    }
  }

  @override
  String toString() => 'ApiException($code): $message';
}
