import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../camera/data/models/photo_models.dart';
import '../../camera/data/photo_repository.dart';
import '../data/gallery_saver.dart';
import '../data/receive_service.dart';

part 'receive_controller.freezed.dart';
part 'receive_controller.g.dart';

enum ReceiveItemStatus { idle, working, saved, failed, ackPending }

@freezed
abstract class ReceiveItem with _$ReceiveItem {
  const factory ReceiveItem({
    required PhotoWithUrl photo,
    required ReceiveItemStatus status,
    @Default(false) bool selected,
  }) = _ReceiveItem;
}

@freezed
abstract class ReceiveState with _$ReceiveState {
  const ReceiveState._();

  const factory ReceiveState({
    required DateTime deadline,
    required List<ReceiveItem> items,
    @Default(false) bool permissionDenied,
    @Default(false) bool running,
  }) = _ReceiveState;

  List<ReceiveItem> get remaining =>
      items.where((i) => i.status != ReceiveItemStatus.saved).toList();

  bool get hasSelection => items.any((i) => i.selected);
}

/// 수령 화면 상태. 저장 성공한 장만 서버에 ack 한다.
@riverpod
class ReceiveController extends _$ReceiveController {
  @override
  Future<ReceiveState> build(String dateId) async {
    final receivable =
        await ref.watch(photoRepositoryProvider).receivable(dateId);
    return ReceiveState(
      deadline: receivable.receiveDeadlineAt,
      items: [
        for (final photo in receivable.items)
          ReceiveItem(
            photo: photo,
            // 대표 사진은 받은 뒤에도 목록에 남는다.
            status: photo.receivedAt != null
                ? ReceiveItemStatus.saved
                : ReceiveItemStatus.idle,
          ),
      ],
    );
  }

  ReceiveState? get _current => state.value;

  void _update(ReceiveState Function(ReceiveState s) change) {
    final current = _current;
    if (current != null && ref.mounted) state = AsyncData(change(current));
  }

  void _setStatus(String photoId, ReceiveItemStatus status) => _update(
        (s) => s.copyWith(items: [
          for (final item in s.items)
            item.photo.id == photoId
                ? item.copyWith(status: status, selected: false)
                : item,
        ]),
      );

  void toggleSelect(String photoId) => _update(
        (s) => s.copyWith(items: [
          for (final item in s.items)
            item.photo.id == photoId
                ? item.copyWith(selected: !item.selected)
                : item,
        ]),
      );

  Future<void> receiveAll() =>
      _receive((_current?.remaining ?? const []).map((i) => i.photo.id));

  Future<void> receiveSelected() => _receive(
        (_current?.items ?? const [])
            .where((i) => i.selected && i.status != ReceiveItemStatus.saved)
            .map((i) => i.photo.id),
      );

  Future<void> retry(String photoId) => _receive([photoId]);

  Future<void> _receive(Iterable<String> photoIds) async {
    final ids = photoIds.toList();
    final current = _current;
    if (ids.isEmpty || current == null || current.running) return;
    // 권한 요청을 기다리는 동안 중복 실행되지 않도록 먼저 표시한다.
    _update((s) => s.copyWith(running: true));
    try {
      if (!await ref.read(gallerySaverProvider).ensureAccess()) {
        _update((s) => s.copyWith(permissionDenied: true));
        return;
      }
      _update((s) => s.copyWith(permissionDenied: false));
      final fresh = await _freshUrls();
      final service = ref.read(receiveServiceProvider);
      for (final id in ids) {
        final item = fresh.where((i) => i.photo.id == id).firstOrNull;
        if (item == null || !ref.mounted) continue;
        _setStatus(id, ReceiveItemStatus.working);
        final outcome = await service.receive(
          item.photo,
          alreadySaved: item.status == ReceiveItemStatus.ackPending,
        );
        _apply(id, outcome);
        if (outcome == ReceiveOutcome.accessDenied) break;
      }
    } finally {
      _update((s) => s.copyWith(running: false));
    }
  }

  void _apply(String id, ReceiveOutcome outcome) {
    switch (outcome) {
      case ReceiveOutcome.saved:
        _setStatus(id, ReceiveItemStatus.saved);
      case ReceiveOutcome.saveFailed:
        _setStatus(id, ReceiveItemStatus.failed);
      case ReceiveOutcome.ackFailed:
        _setStatus(id, ReceiveItemStatus.ackPending);
      case ReceiveOutcome.accessDenied:
        _setStatus(id, ReceiveItemStatus.idle);
        _update((s) => s.copyWith(permissionDenied: true));
    }
  }

  /// presigned GET 은 15분짜리라 시작할 때 새 URL 로 바꾼다. 실패하면 기존 URL 을 쓴다.
  Future<List<ReceiveItem>> _freshUrls() async {
    final items = _current?.items ?? const <ReceiveItem>[];
    try {
      final latest = await ref.read(photoRepositoryProvider).receivable(dateId);
      final byId = {for (final p in latest.items) p.id: p};
      final refreshed = [
        for (final item in items)
          item.copyWith(photo: byId[item.photo.id] ?? item.photo),
      ];
      _update((s) => s.copyWith(items: [
            for (final item in s.items)
              item.copyWith(photo: byId[item.photo.id] ?? item.photo),
          ]));
      return refreshed;
    } catch (_) {
      return items;
    }
  }
}
