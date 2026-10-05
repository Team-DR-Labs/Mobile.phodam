import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/logger/app_logger.dart';
import '../../camera/data/models/photo_models.dart';
import '../../camera/data/photo_repository.dart';
import '../../camera/data/photo_transfer.dart';
import '../../camera/data/upload_queue.dart';
import 'gallery_saver.dart';

part 'receive_service.g.dart';

enum ReceiveOutcome {
  /// 사진첩 저장과 서버 확인(ack) 모두 성공.
  saved,

  /// 다운로드·저장 실패. ack 하지 않았으므로 서버에 남아 다시 받을 수 있다.
  saveFailed,

  /// 사진첩 권한 거부. ack 하지 않았다.
  accessDenied,

  /// 저장은 됐지만 ack 실패. 다시 저장하지 말고 ack 만 재시도한다.
  ackFailed,
}

/// 사진 한 장 수령: 다운로드 → 사진첩 저장 → **저장 성공 시에만** ack → 로컬 큐 정리.
class ReceiveService {
  ReceiveService({
    required this.repository,
    required this.transfer,
    required this.gallery,
    required this.tempDir,
    required this.onReceived,
    this.log,
  });

  final PhotoRepository repository;
  final PhotoTransfer transfer;
  final GallerySaver gallery;
  final Future<Directory> Function() tempDir;

  /// ack 성공 후 호출(로컬 업로드 큐 파일 정리).
  final Future<void> Function(String photoId) onReceived;
  final void Function(String message, Object error)? log;

  Future<ReceiveOutcome> receive(
    PhotoWithUrl photo, {
    bool alreadySaved = false,
  }) async {
    if (!alreadySaved) {
      final outcome = await _save(photo);
      if (outcome != null) return outcome;
    }
    try {
      await repository.ackReceived(photo.id);
    } catch (e) {
      log?.call('수령 확인 실패 ${photo.id}', e);
      return ReceiveOutcome.ackFailed;
    }
    try {
      await onReceived(photo.id);
    } catch (e) {
      // 저장·ack 는 끝났으므로 결과는 성공이다. 로컬 정리는 보관 기한 정리에 맡긴다.
      log?.call('수령 후 로컬 정리 실패 ${photo.id}', e);
    }
    return ReceiveOutcome.saved;
  }

  /// 성공하면 null, 실패하면 결과.
  Future<ReceiveOutcome?> _save(PhotoWithUrl photo) async {
    final path = p.join((await tempDir()).path, 'receive_${photo.id}.jpg');
    try {
      await transfer.download(photo.url, path);
      await gallery.saveImage(path);
      return null;
    } on GalleryAccessDenied {
      return ReceiveOutcome.accessDenied;
    } catch (e) {
      log?.call('사진 저장 실패 ${photo.id}', e);
      return ReceiveOutcome.saveFailed;
    } finally {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    }
  }
}

/// 다운로드 임시 폴더.
@Riverpod(keepAlive: true)
Future<Directory> Function() receiveTempDir(Ref ref) => getTemporaryDirectory;

/// keepAlive: onReceived 가 이 provider 의 ref 를 쓰므로, 수령 루프 도중
/// autoDispose 로 ref 가 끊기면 안 된다.
@Riverpod(keepAlive: true)
ReceiveService receiveService(Ref ref) {
  final logger = ref.watch(appLoggerProvider);
  return ReceiveService(
    repository: ref.watch(photoRepositoryProvider),
    transfer: ref.watch(photoTransferProvider),
    gallery: ref.watch(gallerySaverProvider),
    tempDir: ref.watch(receiveTempDirProvider),
    onReceived: (id) => ref.read(uploadQueueProvider.notifier).remove(id),
    log: (message, error) => logger.w(message, error: error),
  );
}
