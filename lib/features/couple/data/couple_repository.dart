import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/dio_provider.dart';
import '../../../mock/mock_backend.dart';
import 'models/couple_models.dart';

part 'couple_repository.g.dart';

@RestApi()
abstract class CoupleApi {
  factory CoupleApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) =
      _CoupleApi;

  @GET('/couple')
  Future<Couple> getCouple();

  @POST('/couple/invites')
  Future<Invite> createInvite();

  @POST('/couple/join')
  Future<Couple> join(@Body() Map<String, dynamic> body);
}

abstract interface class CoupleRepository {
  Future<Invite> createInvite();

  Future<Couple> join(String code);
}

class ApiCoupleRepository implements CoupleRepository {
  ApiCoupleRepository(this._api);

  final CoupleApi _api;

  @override
  Future<Invite> createInvite() => guardApi(_api.createInvite);

  @override
  Future<Couple> join(String code) =>
      guardApi(() => _api.join({'code': code}));
}

class MockCoupleRepository implements CoupleRepository {
  MockCoupleRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<Invite> createInvite() async => _backend.createInvite();

  @override
  Future<Couple> join(String code) async => _backend.joinCouple(code);
}

@Riverpod(keepAlive: true)
CoupleRepository coupleRepository(Ref ref) {
  if (Env.useMock) return MockCoupleRepository(ref.watch(mockBackendProvider));
  return ApiCoupleRepository(CoupleApi(ref.watch(dioProvider)));
}
