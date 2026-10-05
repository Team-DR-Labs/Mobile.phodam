import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';

/// `POST /auth/refresh` 로 토큰을 회전하고 저장한다.
///
/// 인증 인터셉터가 없는 별도 [Dio] 를 써야 재귀 갱신이 일어나지 않는다.
class TokenRefresherService {
  TokenRefresherService({required Dio plainDio, required this._storage})
      : _dio = plainDio;

  final Dio _dio;
  final SecureStorage _storage;

  Future<String?> refresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final body = response.data!;
      final tokens = AuthTokens(
        accessToken: body['access_token'] as String,
        refreshToken: body['refresh_token'] as String,
      );
      await _storage.writeTokens(tokens);
      return tokens.accessToken;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _storage.clearTokens();
        return null;
      }
      rethrow;
    }
  }
}
