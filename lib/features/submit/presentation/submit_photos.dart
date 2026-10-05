import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../camera/data/models/photo_models.dart';
import '../../camera/data/models/queued_photo.dart';
import '../../camera/data/photo_repository.dart';
import '../../camera/data/upload_queue.dart';

part 'submit_photos.g.dart';

/// 대표 사진 후보 한 장. 업로드가 끝난 사진만 고를 수 있다.
class SelectablePhoto {
  const SelectablePhoto({
    required this.photoId,
    required this.createdAt,
    required this.uploaded,
    this.localPath,
    this.url,
  });

  final String photoId;
  final DateTime createdAt;
  final bool uploaded;

  /// 기기에 남은 처리본(우선 표시).
  final String? localPath;

  /// 서버 미리보기 URL. 앱 안에서 보여주기만 한다.
  final String? url;
}

/// 서버 목록(uploaded)과 로컬 업로드 큐(pending)를 합친다.
List<SelectablePhoto> mergeSelectable(
  List<PhotoWithUrl> server,
  List<QueuedPhoto> local,
) {
  final serverIds = server.map((p) => p.id).toSet();
  final merged = [
    for (final photo in server)
      if (photo.status == PhotoStatus.uploaded ||
          photo.status == PhotoStatus.archived)
        SelectablePhoto(
          photoId: photo.id,
          createdAt: photo.createdAt,
          uploaded: true,
          localPath: local.byId(photo.id)?.filePath,
          url: photo.url,
        ),
    for (final item in local)
      if (!serverIds.contains(item.photoId))
        SelectablePhoto(
          photoId: item.photoId,
          createdAt: item.createdAt,
          uploaded: false,
          localPath: item.filePath,
        ),
  ];
  return merged..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

/// 이 데이트에서 내가 찍은 사진. 업로드 큐가 바뀌면 다시 계산한다.
@riverpod
Future<List<SelectablePhoto>> selectablePhotos(Ref ref, String dateId) async {
  final queue = await ref.watch(uploadQueueProvider.future);
  final server = await ref.watch(photoRepositoryProvider).myPhotos(dateId);
  return mergeSelectable(server, queue.forDate(dateId));
}

const captionMaxRunes = 200;

/// 서버와 같은 기준(앞뒤 공백 제거 후 유니코드 rune 수)으로 센다.
int captionLength(String caption) => caption.trim().runes.length;

/// 빈 글은 null 로 보낸다.
String? normalizeCaption(String caption) {
  final trimmed = caption.trim();
  return trimmed.isEmpty ? null : trimmed;
}
