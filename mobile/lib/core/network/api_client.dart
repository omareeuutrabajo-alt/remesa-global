import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'api_exception.dart';

/// Cliente HTTP de la app.
///
/// Responsabilidades:
///  • adjuntar el access token en cada petición,
///  • renovar el token automáticamente ante un 401 (una sola vez y en cola),
///  • notificar al controlador de sesión cuando la sesión es irrecuperable,
///  • convertir cualquier error de red en [ApiException].
class ApiClient {
  ApiClient({required SecureStorage storage, Dio? dio})
      // ignore: prefer_initializing_formals
      : _storage = storage,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = AppConfig.apiBaseUrl
      ..connectTimeout = AppConfig.connectTimeout
      ..receiveTimeout = AppConfig.receiveTimeout
      ..headers = {'Accept': 'application/json'}
      // Nosotros decidimos qué es error: así los 4xx pasan por el interceptor.
      ..validateStatus = (status) => status != null && status < 400;

    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: false,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        logPrint: (o) => debugPrint('[api] $o'),
      ));
    }
  }

  final Dio _dio;
  final SecureStorage _storage;

  /// Se dispara cuando el refresh falla: la capa de sesión debe cerrar sesión.
  void Function()? onSessionExpired;

  Completer<bool>? _refreshing;

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['skipAuth'] != true) {
      final token = await _storage.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final response = error.response;
    final isAuthRoute = error.requestOptions.path.contains('/auth/refresh') ||
        error.requestOptions.extra['skipAuth'] == true;
    final code = (response?.data is Map && (response!.data as Map)['error'] is Map)
        ? ((response.data as Map)['error'] as Map)['code']?.toString()
        : null;

    final puedeRenovar = response?.statusCode == 401 &&
        !isAuthRoute &&
        error.requestOptions.extra['retried'] != true &&
        (code == 'TOKEN_EXPIRED' || code == 'TOKEN_INVALID' || code == 'TOKEN_MISSING');

    if (puedeRenovar && await _refreshToken()) {
      try {
        final options = error.requestOptions..extra['retried'] = true;
        final retry = await _dio.fetch(options);
        return handler.resolve(retry);
      } on DioException catch (e) {
        return handler.next(e);
      }
    }
    handler.next(error);
  }

  /// Renueva el par de tokens. Las peticiones concurrentes esperan al mismo
  /// intento en lugar de disparar N refrescos (evita invalidar la rotación).
  Future<bool> _refreshToken() async {
    if (_refreshing != null) return _refreshing!.future;
    final completer = Completer<bool>();
    _refreshing = completer;

    try {
      final refresh = await _storage.refreshToken;
      if (refresh == null || refresh.isEmpty) {
        completer.complete(false);
        onSessionExpired?.call();
        return false;
      }

      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
        options: Options(extra: {'skipAuth': true}),
      );

      final tokens = (res.data?['data']?['tokens']) as Map<String, dynamic>?;
      if (tokens == null) {
        completer.complete(false);
        onSessionExpired?.call();
        return false;
      }

      await _storage.saveTokens(
        access: tokens['accessToken'] as String,
        refresh: tokens['refreshToken'] as String,
      );
      completer.complete(true);
      return true;
    } catch (_) {
      await _storage.clearSession();
      completer.complete(false);
      onSessionExpired?.call();
      return false;
    } finally {
      _refreshing = null;
    }
  }

  // ───────────────────────── Verbos ─────────────────────────

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _unwrap(() => _dio.get<Map<String, dynamic>>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(
    String path, {
    Object? data,
    bool skipAuth = false,
  }) =>
      _unwrap(() => _dio.post<Map<String, dynamic>>(
            path,
            data: data,
            options: Options(extra: {'skipAuth': skipAuth}),
          ));

  Future<Map<String, dynamic>> postMultipart(String path, FormData data) =>
      _unwrap(() => _dio.post<Map<String, dynamic>>(path, data: data));

  /// Desempaqueta `{ success, data }` y normaliza los errores.
  Future<Map<String, dynamic>> _unwrap(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final res = await request();
      final body = res.data ?? const {};
      final data = body['data'];
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } catch (e) {
      throw ApiException(code: 'UNEXPECTED', message: 'Error inesperado: $e');
    }
  }
}
