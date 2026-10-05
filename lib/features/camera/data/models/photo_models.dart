import 'package:freezed_annotation/freezed_annotation.dart';

part 'photo_models.freezed.dart';
part 'photo_models.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum PhotoStatus { reserved, uploaded, archived, received, deleted }

@freezed
abstract class Photo with _$Photo {
  const factory Photo({
    required String id,
    required String dateId,
    required PhotoStatus status,
    required bool isRepresentative,
    required DateTime createdAt,
    DateTime? uploadedAt,
    DateTime? receivedAt,
  }) = _Photo;

  factory Photo.fromJson(Map<String, dynamic> json) => _$PhotoFromJson(json);
}

/// Photo + presigned GET URL.
@freezed
abstract class PhotoWithUrl with _$PhotoWithUrl {
  const factory PhotoWithUrl({
    required String id,
    required String dateId,
    required PhotoStatus status,
    required bool isRepresentative,
    required DateTime createdAt,
    DateTime? uploadedAt,
    DateTime? receivedAt,
    required String url,
    required DateTime urlExpiresAt,
  }) = _PhotoWithUrl;

  factory PhotoWithUrl.fromJson(Map<String, dynamic> json) =>
      _$PhotoWithUrlFromJson(json);
}

@freezed
abstract class PhotoList with _$PhotoList {
  const factory PhotoList({required List<PhotoWithUrl> items}) = _PhotoList;

  factory PhotoList.fromJson(Map<String, dynamic> json) =>
      _$PhotoListFromJson(json);
}

/// presigned PUT. 인증 헤더 없이 [headers] 를 그대로 붙여 호출한다.
@freezed
abstract class UploadTarget with _$UploadTarget {
  const factory UploadTarget({
    required String url,
    required String method,
    required Map<String, String> headers,
    required DateTime expiresAt,
  }) = _UploadTarget;

  factory UploadTarget.fromJson(Map<String, dynamic> json) =>
      _$UploadTargetFromJson(json);
}

@freezed
abstract class ShotReservation with _$ShotReservation {
  const factory ShotReservation({
    required Photo photo,
    required UploadTarget upload,
    required int filmBalance,
  }) = _ShotReservation;

  factory ShotReservation.fromJson(Map<String, dynamic> json) =>
      _$ShotReservationFromJson(json);
}

@freezed
abstract class Receivable with _$Receivable {
  const factory Receivable({
    required DateTime receiveDeadlineAt,
    required List<PhotoWithUrl> items,
  }) = _Receivable;

  factory Receivable.fromJson(Map<String, dynamic> json) =>
      _$ReceivableFromJson(json);
}
