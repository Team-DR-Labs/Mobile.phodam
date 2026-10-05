import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/api_error.dart';
import '../../../core/storage/secure_storage.dart';
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
/// 백오프 타이머, 앱 복귀·재시작·온라인 복귀·로그인·제출 화면 진입 때 다시 시도한다.
/// 지금 로그인한 계정이 찍은 사진만 처리하고, 다른 계정 사진은 보존한다.
@Riverpod(keepAlive: true)
class UploadQueue extends _$UploadQueue {
  /// 72시간 + 수령 7일 + 여유. 이보다 오래된 로컬 파일은 지운다.
  static const retention = Duration(days: 11);

  /// 만료 직전 URL 은 쓰지 않는다.
  static const urlMargin = Duration(seconds: 30);

  static const _baseBackoff = Duration(seconds: 5);
  static const _maxBackoff = Duration(minutes: 30);

  /// 실패 횟수에 따른 다음 재시도 간격(5초부터 2배씩, 최대 30분).
  static Duration backoff(int attempts) {
    final seconds = _baseBackoff.inSeconds * pow(2, max(0, attempts - 1));
    return Duration(seconds: min(seconds.toInt(), _maxBackoff.inSeconds));
  }

  Future<void>? _running;
  bool _rerun = false;
  bool _force = false;
  Timer? _retryTimer;

  UploadQueueStore get _store => ref.read(uploadQueueStoreProvider);

  PhotoRepository get _repository => ref.read(photoRepositoryProvider);

  DateTime _now() => ref.read(clockProvider)();

  @override
  Future<List<QueuedPhoto>> build() async {
    ref.onDispose(() => _retryTimer?.cancel());
    final store = ref.watch(uploadQueueStoreProvider);
    final items = await store.load();
    final now = _now();
    final keep = <QueuedPhoto>[];
    for (final item in items) {
      if (now.difference(item.createdAt) < retention) {
        keep.add(item);
      } else {
        await store.delete(item);
      }
    }
    return keep;
  }

  List<QueuedPhoto> get _items => state.value ?? const [];

  /// 상태와 디스크에 한 항목을 반영한다. 이미 지워진 항목은 되살리지 않는다.
  Future<void> _upsert(QueuedPhoto item, {bool insert = false}) async {
    final exists = _items.any((i) => i.photoId == item.photoId);
    if (!exists && !insert) return;
    state = AsyncData([
      if (exists)
        for (final i in _items) i.photoId == item.photoId ? item : i
      else ...[
        ..._items,
        item,
      ],
    ]);
    await _store.put(item);
  }

  Future<void> _update(
    String photoId,
    QueuedPhoto Function(QueuedPhoto item) change,
  ) async {
    final item = _items.byId(photoId);
    if (item != null) await _upsert(change(item));
  }

  /// 처리한 JPEG 을 저장하고 업로드를 시작한다.
  Future<void> add(ShotReservation reservation, Uint8List jpeg) async {
    await future;
    final userId = await ref.read(secureStorageProvider).readUserId() ?? '';
    final path = await _store.writeImage(reservation.photo.id, jpeg);
    await _upsert(
      QueuedPhoto(
        photoId: reservation.photo.id,
        dateId: reservation.photo.dateId,
        userId: userId,
        filePath: path,
        status: QueueStatus.pending,
        createdAt: _now(),
        target: reservation.upload,
      ),
      insert: true,
    );
    unawaited(process());
  }

  /// 대기 중인 사진을 올린다. [force] 면 백오프 대기 중인 사진도 지금 시도한다.
  ///
  /// 이미 도는 중이면 한 바퀴 더 돌도록 표시하고 그 실행의 완료를 돌려준다.
  Future<void> process({bool force = false}) {
    _rerun = true;
    if (force) _force = true;
    final running = _running;
    if (running != null) return running;
    final done = Completer<void>();
    _running = done.future;
    _loop().then(done.complete, onError: done.completeError);
    return done.future;
  }

  Future<void> _loop() async {
    try {
      while (true) {
        // 종료 판단과 _running 해제를 같은 동기 구간에서 해야 add() 신호를 잃지 않는다.
        if (!_rerun || !ref.mounted) {
          _running = null;
          if (ref.mounted) _scheduleRetry();
          return;
        }
        _rerun = false;
        final force = _force;
        _force = false;
        await future;
        final userId = await ref.read(secureStorageProvider).readUserId();
        final now = _now();
        final due = _items
            .where((i) =>
                i.status == QueueStatus.pending &&
                i.userId == userId &&
                (force || i.nextAttemptAt == null || !now.isBefore(i.nextAttemptAt!)))
            .toList();
        for (final item in due) {
          if (!ref.mounted) break;
          await _guarded(item);
        }
      }
    } catch (_) {
      _running = null;
      rethrow;
    }
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final waiting = _items
        .where((i) => i.status == QueueStatus.pending && i.nextAttemptAt != null)
        .map((i) => i.nextAttemptAt!)
        .toList();
    if (waiting.isEmpty) return;
    final next = waiting.reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = next.difference(_now());
    _retryTimer = Timer(delay.isNegative ? Duration.zero : delay, process);
  }

  /// 한 장의 실패가 큐 전체를 멈추지 않게 한다.
  Future<void> _guarded(QueuedPhoto item) async {
    try {
      await _uploadOne(item);
    } catch (e) {
      ref.read(appLoggerProvider).w('업로드 처리 오류 ${item.photoId}', error: e);
    }
  }

  Future<void> _uploadOne(QueuedPhoto item) async {
    if (!File(item.filePath).existsSync()) {
      ref.read(appLoggerProvider).w('업로드할 파일이 없어 큐에서 뺀다 ${item.photoId}');
      await remove(item.photoId);
      return;
    }
    try {
      var target = item.target;
      if (target == null ||
          !_now().isBefore(target.expiresAt.subtract(urlMargin))) {
        target = await _repository.reissueUploadUrl(item.photoId);
        final fresh = target;
        await _update(item.photoId, (i) => i.copyWith(target: fresh));
      }
      await ref.read(photoTransferProvider).upload(target, File(item.filePath));
      await _markUploaded(item.photoId);
    } on ApiException catch (e) {
      await _onFailure(item, e);
    }
  }

  Future<void> _markUploaded(String photoId) async {
    await _repository.complete(photoId);
    await _update(
      photoId,
      (i) => i.copyWith(
        status: QueueStatus.uploaded,
        target: null,
        nextAttemptAt: null,
      ),
    );
  }

  Future<void> _onFailure(QueuedPhoto item, ApiException error) async {
    ref.read(appLoggerProvider).w('업로드 실패 ${item.photoId}', error: error);
    switch (error.code) {
      case ApiErrorCode.photoNotUploaded:
        await _retryLater(item.photoId, clearTarget: true);
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
        await _retryLater(item.photoId, clearTarget: error.statusCode == 403);
    }
  }

  Future<void> _retryLater(String photoId, {required bool clearTarget}) =>
      _update(photoId, (i) {
        final attempts = i.attempts + 1;
        return i.copyWith(
          attempts: attempts,
          nextAttemptAt: _now().add(backoff(attempts)),
          target: clearTarget ? null : i.target,
        );
      });

  /// 로컬 파일과 항목을 지운다(수령 성공 후 정리 등).
  Future<void> remove(String photoId) async {
    await future;
    final item = _items.byId(photoId);
    if (item == null) return;
    state = AsyncData(_items.where((i) => i.photoId != photoId).toList());
    await _store.delete(item);
  }
}

extension QueuedPhotoLookup on List<QueuedPhoto> {
  QueuedPhoto? byId(String photoId) =>
      where((i) => i.photoId == photoId).firstOrNull;

  List<QueuedPhoto> forDate(String dateId) =>
      where((i) => i.dateId == dateId).toList();
}
