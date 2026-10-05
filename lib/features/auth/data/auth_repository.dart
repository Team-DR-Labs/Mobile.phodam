import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/dio_provider.dart';
import '../../../mock/mock_backend.dart';
import 'auth_api.dart';
import 'models/auth_models.dart';

part 'auth_repository.g.dart';

abstract interface class AuthRepository {
  Future<AuthResponse> loginApple({
    required String identityToken,
    String? nickname,
  });

  Future<AuthResponse> loginGoogle({required String idToken});

  Future<AuthResponse> loginDev({required String devId, String? nickname});

  Future<void> logout({required String refreshToken});
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api);

  final AuthApi _api;

  @override
  Future<AuthResponse> loginApple({
    required String identityToken,
    String? nickname,
  }) =>
      guardApi(() => _api.loginApple({
            'identity_token': identityToken,
            'nickname': ?nickname,
          }));

  @override
  Future<AuthResponse> loginGoogle({required String idToken}) =>
      guardApi(() => _api.loginGoogle({'id_token': idToken}));

  @override
  Future<AuthResponse> loginDev({required String devId, String? nickname}) =>
      guardApi(() => _api.loginDev({'dev_id': devId, 'nickname': ?nickname}));

  @override
  Future<void> logout({required String refreshToken}) =>
      guardApi(() => _api.logout({'refresh_token': refreshToken}));
}

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<AuthResponse> loginApple({
    required String identityToken,
    String? nickname,
  }) async =>
      _backend.login('apple-${identityToken.hashCode}', nickname: nickname);

  @override
  Future<AuthResponse> loginGoogle({required String idToken}) async =>
      _backend.login('google-${idToken.hashCode}');

  @override
  Future<AuthResponse> loginDev({
    required String devId,
    String? nickname,
  }) async =>
      _backend.login(devId, nickname: nickname);

  @override
  Future<void> logout({required String refreshToken}) async {}
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  if (Env.useMock) return MockAuthRepository(ref.watch(mockBackendProvider));
  return ApiAuthRepository(AuthApi(ref.watch(dioProvider)));
}
