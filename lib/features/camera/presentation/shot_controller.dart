import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_error.dart';
import '../../me/presentation/me_controller.dart';
import '../data/film_look.dart';
import '../data/photo_repository.dart';
import '../data/upload_queue.dart';

part 'shot_controller.g.dart';

sealed class ShotResult {
  const ShotResult();
}

class ShotSaved extends ShotResult {
  const ShotSaved(this.filmBalance);

  final int filmBalance;
}

/// 서버가 샷 예약을 거절함(FILM_EXHAUSTED, ALREADY_SUBMITTED, DATE_NOT_ACTIVE …).
class ShotRejected extends ShotResult {
  const ShotRejected(this.error);

  final ApiException error;

  /// 이 데이트에서 더 찍을 수 없는 상태.
  bool get dateClosed =>
      error.code == ApiErrorCode.alreadySubmitted ||
      error.code == ApiErrorCode.dateNotActive ||
      error.code == ApiErrorCode.notFound;
}

/// 예약은 됐지만(필름 차감) 촬영·처리에 실패함. 필름은 복구되지 않는다.
class ShotCaptureFailed extends ShotResult {
  const ShotCaptureFailed(this.error);

  final Object error;
}

typedef Capture = Future<Uint8List> Function();

/// 셔터 한 번의 흐름: 촬영과 샷 예약을 동시에 → 색감 처리 → 업로드 큐.
@riverpod
class ShotController extends _$ShotController {
  /// true 면 셔터를 누를 수 없다(처리 중).
  @override
  bool build(String dateId) => false;

  Future<ShotResult> shoot(Capture capture) async {
    if (state) return ShotCaptureFailed(StateError('busy'));
    state = true;
    // 필름은 이미 차감되므로, 처리 중 화면을 떠나도 큐에 넣을 때까지 살아 있어야 한다.
    final link = ref.keepAlive();
    try {
      return await _shoot(capture);
    } finally {
      if (ref.mounted) state = false;
      link.close();
    }
  }

  Future<ShotResult> _shoot(Capture capture) async {
    final repository = ref.read(photoRepositoryProvider);
    final reserving = _settle(() => repository.reserveShot(dateId));
    final capturing = _settle(capture);
    final (reservation, reserveError) = await reserving;
    final (raw, captureError) = await capturing;

    if (reservation == null) {
      final error = ApiException.from(reserveError!);
      if (error.code == ApiErrorCode.filmExhausted) {
        ref.read(meControllerProvider.notifier).setFilmBalance(0);
      }
      return ShotRejected(error);
    }
    ref
        .read(meControllerProvider.notifier)
        .setFilmBalance(reservation.filmBalance);
    if (raw == null) return ShotCaptureFailed(captureError!);
    try {
      final jpeg = await ref.read(filmProcessorProvider)(raw);
      await ref.read(uploadQueueProvider.notifier).add(reservation, jpeg);
      return ShotSaved(reservation.filmBalance);
    } catch (e) {
      return ShotCaptureFailed(e);
    }
  }
}

/// 동기·비동기 예외를 모두 (값, 오류) 로 바꾼다. 호출은 즉시 시작한다.
Future<(T?, Object?)> _settle<T>(Future<T> Function() start) async {
  try {
    return (await start(), null);
  } catch (e) {
    return (null, e);
  }
}
