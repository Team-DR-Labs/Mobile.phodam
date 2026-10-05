import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/dio_provider.dart';
import '../../../mock/mock_backend.dart';
import 'models/photo_models.dart';

part 'photo_repository.g.dart';

@RestApi()
abstract class PhotoApi {
  factory PhotoApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) =
      _PhotoApi;

  @POST('/dates/{id}/shots')
  Future<ShotReservation> reserveShot(@Path('id') String dateId);

  @GET('/dates/{id}/my-photos')
  Future<PhotoList> myPhotos(@Path('id') String dateId);

  @GET('/dates/{id}/receivable')
  Future<Receivable> receivable(@Path('id') String dateId);

  @POST('/photos/{id}/upload-url')
  Future<UploadTarget> reissueUploadUrl(@Path('id') String photoId);

  @POST('/photos/{id}/complete')
  Future<Photo> complete(@Path('id') String photoId);

  @POST('/photos/{id}/received')
  Future<Photo> ackReceived(@Path('id') String photoId);
}

abstract interface class PhotoRepository {
  /// 셔터 1회: 서버에서 필름 1장을 차감하고 업로드 URL 을 받는다.
  Future<ShotReservation> reserveShot(String dateId);

  /// 앱 내 미리보기 전용. 저장·공유 UI 에 쓰지 않는다.
  Future<List<PhotoWithUrl>> myPhotos(String dateId);

  Future<Receivable> receivable(String dateId);

  Future<UploadTarget> reissueUploadUrl(String photoId);

  Future<Photo> complete(String photoId);

  /// 기기 저장 성공 후에만 호출한다.
  Future<Photo> ackReceived(String photoId);
}

class ApiPhotoRepository implements PhotoRepository {
  ApiPhotoRepository(this._api);

  final PhotoApi _api;

  @override
  Future<ShotReservation> reserveShot(String dateId) =>
      guardApi(() => _api.reserveShot(dateId));

  @override
  Future<List<PhotoWithUrl>> myPhotos(String dateId) =>
      guardApi(() async => (await _api.myPhotos(dateId)).items);

  @override
  Future<Receivable> receivable(String dateId) =>
      guardApi(() => _api.receivable(dateId));

  @override
  Future<UploadTarget> reissueUploadUrl(String photoId) =>
      guardApi(() => _api.reissueUploadUrl(photoId));

  @override
  Future<Photo> complete(String photoId) =>
      guardApi(() => _api.complete(photoId));

  @override
  Future<Photo> ackReceived(String photoId) =>
      guardApi(() => _api.ackReceived(photoId));
}

class MockPhotoRepository implements PhotoRepository {
  MockPhotoRepository(this._backend);

  final MockBackend _backend;

  @override
  Future<ShotReservation> reserveShot(String dateId) async =>
      _backend.reserveShot(dateId);

  @override
  Future<List<PhotoWithUrl>> myPhotos(String dateId) async =>
      _backend.myPhotos(dateId);

  @override
  Future<Receivable> receivable(String dateId) async =>
      _backend.receivable(dateId);

  @override
  Future<UploadTarget> reissueUploadUrl(String photoId) async =>
      _backend.reissueUploadUrl(photoId);

  @override
  Future<Photo> complete(String photoId) async => _backend.complete(photoId);

  @override
  Future<Photo> ackReceived(String photoId) async =>
      _backend.ackReceived(photoId);
}

@Riverpod(keepAlive: true)
PhotoRepository photoRepository(Ref ref) {
  if (Env.useMock) return MockPhotoRepository(ref.watch(mockBackendProvider));
  return ApiPhotoRepository(PhotoApi(ref.watch(dioProvider)));
}
