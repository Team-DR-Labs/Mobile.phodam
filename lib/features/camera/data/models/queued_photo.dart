import 'package:freezed_annotation/freezed_annotation.dart';

import 'photo_models.dart';

part 'queued_photo.freezed.dart';
part 'queued_photo.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum QueueStatus {
  /// 아직 서버가 업로드 완료를 확인하지 않음.
  pending,

  /// complete 성공. 로컬 파일은 수령 후 지운다.
  uploaded,
}

/// 기기에 남겨 둔 촬영 사진 한 장.
@freezed
abstract class QueuedPhoto with _$QueuedPhoto {
  const factory QueuedPhoto({
    required String photoId,
    required String dateId,
    required String filePath,
    required QueueStatus status,
    required DateTime createdAt,
    UploadTarget? target,
    @Default(0) int attempts,
  }) = _QueuedPhoto;

  factory QueuedPhoto.fromJson(Map<String, dynamic> json) =>
      _$QueuedPhotoFromJson(json);
}
