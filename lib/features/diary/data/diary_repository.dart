import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/dio_provider.dart';
import '../../../mock/mock_backend.dart';
import 'models/diary_models.dart';

part 'diary_repository.g.dart';

@RestApi()
abstract class DiaryApi {
  factory DiaryApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) =
      _DiaryApi;

  @GET('/diaries')
  Future<DiaryList> list(
    @Query('cursor') String? cursor,
    @Query('limit') int limit,
  );

  @GET('/diaries/{id}')
  Future<DiaryDetail> detail(@Path('id') String dateId);
}

abstract interface class DiaryRepository {
  Future<DiaryList> list({String? cursor, int limit = 20});

  Future<DiaryDetail> detail(String dateId);
}

class ApiDiaryRepository implements DiaryRepository {
  ApiDiaryRepository(this._api);

  final DiaryApi _api;

  @override
  Future<DiaryList> list({String? cursor, int limit = 20}) =>
      guardApi(() => _api.list(cursor, limit));

  @override
  Future<DiaryDetail> detail(String dateId) =>
      guardApi(() => _api.detail(dateId));
}

class MockDiaryRepository implements DiaryRepository {
  MockDiaryRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<DiaryList> list({String? cursor, int limit = 20}) async =>
      _backend.diaries(cursor: cursor, limit: limit);

  @override
  Future<DiaryDetail> detail(String dateId) async => _backend.diary(dateId);
}

@Riverpod(keepAlive: true)
DiaryRepository diaryRepository(Ref ref) {
  if (Env.useMock) return MockDiaryRepository(ref.watch(mockBackendProvider));
  return ApiDiaryRepository(DiaryApi(ref.watch(dioProvider)));
}
