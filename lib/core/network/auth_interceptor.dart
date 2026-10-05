import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';

/// 새 액세스 토큰을 돌려준다. 리프레시 토큰이 무효면 null,
/// 네트워크 오류처럼 판단할 수 없으면 예외를 던진다.
typedef TokenRefresher = Future<String?> Function();

/// 액세스 토큰을 붙이고, 401 이면 토큰을 한 번 갱신한 뒤 재시도한다.
///
/// - 동시에 여러 요청이 401 을 받아도 갱신은 한 번만 수행한다.
/// - 갱신이 무효로 끝나면 [onSessionExpired] 를 부르고 원래 오류를 전달한다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._storage,
    required this._retryDio,
    required this._refresh,
    required this._onSessionExpired,
  });

  final SecureStorage _storage;
  final Dio _retryDio;
  final TokenRefresher _refresh;
  final void Function() _onSessionExpired;

  static const _retriedKey = 'auth_retried';
  static const _publicPaths = {
    '/auth/apple',
    '/auth/google',
    '/auth/dev',
    '/auth/refresh',
  };

  Future<String?>? _inflight;

  static bool _isPublic(RequestOptions options) =>
      _publicPaths.contains(options.path);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options)) {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final shouldRefresh = err.response?.statusCode == 401 &&
        !_isPublic(options) &&
        options.extra[_retriedKey] != true;
    if (!shouldRefresh) return handler.next(err);

    final String? token;
    try {
      token = await _validToken(options);
    } catch (_) {
      return handler.next(err);
    }
    if (token == null) {
      _onSessionExpired();
      return handler.next(err);
    }

    options.headers['Authorization'] = 'Bearer $token';
    options.extra[_retriedKey] = true;
    try {
      handler.resolve(await _retryDio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// 이미 다른 요청이 토큰을 갱신했다면 그 토큰을 쓰고, 아니면 갱신한다.
  Future<String?> _validToken(RequestOptions options) async {
    final current = await _storage.readAccessToken();
    final used = options.headers['Authorization'];
    if (current != null && used != 'Bearer $current') return current;
    return _refreshOnce();
  }

  Future<String?> _refreshOnce() {
    return _inflight ??= _refresh().whenComplete(() => _inflight = null);
  }
}
