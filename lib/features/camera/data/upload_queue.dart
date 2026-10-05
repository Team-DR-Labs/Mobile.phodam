import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/api_error.dart';
import '../../../core/time/clock.dart';
import 'models/photo_models.dart';
import 'models/queued_photo.dart';
import 'photo_repository.dart';
import 'photo_transfer.dart';
import 'upload_queue_store.dart';

part 'upload_queue.g.dart';

/// 촬영 사진 업로드 큐.
///
/// presigned PUT → `/photos/{id}/complete` 순서로 올린다. 실패하면 큐에 남기고
/// 앱 복귀·재시작·온라인 복귀 때 [process] 로 다시 시도한다.
@Riverpod(keepAlive: true)
class UploadQueue extends _$UploadQueue {
  /// 72시간 + 수령 7일 + 여유. 이보다 오래된 로컬 파일은 지운다.
  static const retention = Duration(days: 11);

  /// 만료 직전 URL 은 쓰지 않는다.
  static const urlMargin = Duration(seconds: 30);

  Future<void>? _running;
  bool _rerun = false;

  UploadQueueStore get _store => ref.read(uploadQueueStoreProvider);

  PhotoRepository get _repository => ref.read(photoRepositoryProvider);

  DateTime _now() => ref.read(clockProvider)();

  @override
  Future<List<QueuedPhoto>> build() async {
    final store = ref.watch(uploadQueueStoreProvider);
    final items = await store.load();
    final now = _now();
    final keep = <QueuedPhoto>[];
    for (final item in items) {
      if (now.difference(item.createdAt) < retention) {
        keep.add(item);
      } else {
        await store.deleteImage(item.filePath);
      }
    }
    if (keep.length != items.length) await store.save(keep);
    return keep;
  }

  List<QueuedPhoto> get _items => state.value ?? const [];

  Future<void> _commit(List<QueuedPhoto> items) async {
    state = AsyncData(items);
    await _store.save(items);
  }

  Future<void> _replace(
    String photoId,
    QueuedPhoto Function(QueuedPhoto item) update,
  ) =>
      _commit([
        for (final item in _items)
          item.photoId == photoId ? update(item) : item,
      ]);

  /// 처리한 JPEG 을 저장하고 업로드를 시작한다.
  Future<void> add(ShotReservation reservation, Uint8List jpeg) async {
    await future;
    final path = await _store.writeImage(reservation.photo.id, jpeg);
    await _commit([
      ..._items,
      QueuedPhoto(
        photoId: reservation.photo.id,
        dateId: reservation.photo.dateId,
        filePath: path,
        status: QueueStatus.pending,
        createdAt: _now(),
        target: reservation.upload,
      ),
    ]);
    if (_running != null) {
      _rerun = true;
    } else {
      unawaited(process());
    }
  }

  /// 대기 중인 사진을 순서대로 올린다.
  ///
  /// 이미 도는 중이면 그 실행이 끝날 때 완료된다. 도는 중 추가된 사진은 이어서 올린다.
  Future<void> process() {
    final running = _running;
    if (running != null) return running;
    return _running = _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    do {
      _rerun = false;
      await future;
      final pending =
          _items.where((i) => i.status == QueueStatus.pending).toList();
      for (final item in pending) {
        if (!ref.mounted) return;
        await _uploadOne(item);
      }
    } while (_rerun && ref.mounted);
  }

  Future<void> _uploadOne(QueuedPhoto item) async {
    try {
      var target = item.target;
      if (target == null ||
          !_now().isBefore(target.expiresAt.subtract(urlMargin))) {
        target = await _repository.reissueUploadUrl(item.photoId);
        final fresh = target;
        await _replace(item.photoId, (i) => i.copyWith(target: fresh));
      }
      await ref.read(photoTransferProvider).upload(target, File(item.filePath));
      await _markUploaded(item.photoId);
    } on ApiException catch (e) {
      await _onFailure(item, e);
    } on FileSystemException catch (e) {
      ref.read(appLoggerProvider).w('업로드할 파일이 없어 큐에서 뺀다', error: e);
      await remove(item.photoId);
    }
  }

  Future<void> _markUploaded(String photoId) async {
    await _repository.complete(photoId);
    await _replace(
      photoId,
      (i) => i.copyWith(status: QueueStatus.uploaded, target: null),
    );
  }

  Future<void> _onFailure(QueuedPhoto item, ApiException error) async {
    ref.read(appLoggerProvider).w('업로드 실패 ${item.photoId}', error: error);
    switch (error.code) {
      case ApiErrorCode.photoNotUploaded:
        await _replace(item.photoId, (i) => i.copyWith(target: null));
      case ApiErrorCode.notFound:
        // URL 재발급은 reserved 만 된다. 이미 올라간 사진일 수 있으니 확인한다.
        try {
          await _markUploaded(item.photoId);
        } on ApiException {
          await remove(item.photoId);
        }
      case ApiErrorCode.dateNotActive ||
            ApiErrorCode.alreadySubmitted ||
            ApiErrorCode.dateNotJoined ||
            ApiErrorCode.photoInvalid ||
            ApiErrorCode.forbidden:
        // 더 이상 올릴 수 없는 사진.
        await remove(item.photoId);
      default:
        final expiredUrl = error.statusCode == 403;
        await _replace(
          item.photoId,
          (i) => i.copyWith(
            attempts: i.attempts + 1,
            target: expiredUrl ? null : i.target,
          ),
        );
    }
  }

  /// 로컬 파일과 항목을 지운다(수령 성공 후 정리 등).
  Future<void> remove(String photoId) async {
    await future;
    final item = _items.where((i) => i.photoId == photoId).firstOrNull;
    if (item == null) return;
    await _store.deleteImage(item.filePath);
    await _commit(_items.where((i) => i.photoId != photoId).toList());
  }
}

extension QueuedPhotoLookup on List<QueuedPhoto> {
  QueuedPhoto? byId(String photoId) =>
      where((i) => i.photoId == photoId).firstOrNull;

  List<QueuedPhoto> forDate(String dateId) =>
      where((i) => i.dateId == dateId).toList();
}
