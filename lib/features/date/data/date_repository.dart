import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/dio_provider.dart';
import '../../../mock/mock_backend.dart';
import 'models/date_models.dart';

part 'date_repository.g.dart';

@RestApi()
abstract class DateApi {
  factory DateApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) =
      _DateApi;

  @POST('/dates')
  Future<DateView> startDate();

  @GET('/dates/{id}')
  Future<DateView> getDate(@Path('id') String dateId);

  @POST('/dates/{id}/join')
  Future<DateView> joinDate(@Path('id') String dateId);

  @POST('/dates/{id}/submit')
  Future<DateView> submit(
    @Path('id') String dateId,
    @Body() Map<String, dynamic> body,
  );
}

abstract interface class DateRepository {
  Future<DateView> startDate();

  Future<DateView> getDate(String dateId);

  Future<DateView> joinDate(String dateId);

  Future<DateView> submit(
    String dateId, {
    required String photoId,
    String? caption,
  });
}

class ApiDateRepository implements DateRepository {
  ApiDateRepository(this._api);

  final DateApi _api;

  @override
  Future<DateView> startDate() => guardApi(_api.startDate);

  @override
  Future<DateView> getDate(String dateId) =>
      guardApi(() => _api.getDate(dateId));

  @override
  Future<DateView> joinDate(String dateId) =>
      guardApi(() => _api.joinDate(dateId));

  @override
  Future<DateView> submit(
    String dateId, {
    required String photoId,
    String? caption,
  }) =>
      guardApi(() => _api.submit(
            dateId,
            {'photo_id': photoId, 'caption': caption},
          ));
}

class MockDateRepository implements DateRepository {
  MockDateRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<DateView> startDate() async => _backend.startDate();

  @override
  Future<DateView> getDate(String dateId) async => _backend.getDate(dateId);

  @override
  Future<DateView> joinDate(String dateId) async => _backend.joinDate(dateId);

  @override
  Future<DateView> submit(
    String dateId, {
    required String photoId,
    String? caption,
  }) async =>
      _backend.submit(dateId, photoId: photoId, caption: caption);
}

@Riverpod(keepAlive: true)
DateRepository dateRepository(Ref ref) {
  if (Env.useMock) return MockDateRepository(ref.watch(mockBackendProvider));
  return ApiDateRepository(DateApi(ref.watch(dioProvider)));
}
