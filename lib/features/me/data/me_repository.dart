import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/dio_provider.dart';
import '../../../mock/mock_backend.dart';
import 'models/me.dart';

part 'me_repository.g.dart';

@RestApi()
abstract class MeApi {
  factory MeApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) =
      _MeApi;

  @GET('/me')
  Future<Me> getMe();

  @PATCH('/me')
  Future<Me> updateMe(@Body() Map<String, dynamic> body);

  @PUT('/me/devices')
  Future<void> registerDevice(@Body() Map<String, dynamic> body);
}

enum DevicePlatform { ios, android }

abstract interface class MeRepository {
  Future<Me> getMe();

  Future<Me> updateNickname(String nickname);

  Future<void> registerDevice({
    required String fcmToken,
    required DevicePlatform platform,
  });
}

class ApiMeRepository implements MeRepository {
  ApiMeRepository(this._api);

  final MeApi _api;

  @override
  Future<Me> getMe() => guardApi(_api.getMe);

  @override
  Future<Me> updateNickname(String nickname) =>
      guardApi(() => _api.updateMe({'nickname': nickname}));

  @override
  Future<void> registerDevice({
    required String fcmToken,
    required DevicePlatform platform,
  }) =>
      guardApi(() => _api.registerDevice(
            {'fcm_token': fcmToken, 'platform': platform.name},
          ));
}

class MockMeRepository implements MeRepository {
  MockMeRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<Me> getMe() async => _backend.me();

  @override
  Future<Me> updateNickname(String nickname) async =>
      _backend.updateNickname(nickname);

  @override
  Future<void> registerDevice({
    required String fcmToken,
    required DevicePlatform platform,
  }) async {}
}

@Riverpod(keepAlive: true)
MeRepository meRepository(Ref ref) {
  if (Env.useMock) return MockMeRepository(ref.watch(mockBackendProvider));
  return ApiMeRepository(MeApi(ref.watch(dioProvider)));
}
