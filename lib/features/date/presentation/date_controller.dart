import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../me/presentation/me_controller.dart';
import '../data/date_repository.dart';
import '../data/models/date_models.dart';

part 'date_controller.g.dart';

/// 데이트 한 건 조회 (`GET /dates/{id}`).
@riverpod
Future<DateView> dateDetail(Ref ref, String dateId) =>
    ref.watch(dateRepositoryProvider).getDate(dateId);

/// 데이트 시작·참여. 성공하면 `/me` 와 상세를 갱신한다.
@Riverpod(keepAlive: true)
DateActions dateActions(Ref ref) => DateActions(ref);

class DateActions {
  DateActions(this._ref);

  final Ref _ref;

  DateRepository get _repository => _ref.read(dateRepositoryProvider);

  Future<DateView> start() async {
    final date = await _repository.startDate();
    await _ref.read(meControllerProvider.notifier).reload();
    return date;
  }

  /// 상대 참여 = 내 주제 확인 (멱등).
  Future<DateView> join(String dateId) async {
    final date = await _repository.joinDate(dateId);
    _ref.invalidate(dateDetailProvider(dateId));
    await _ref.read(meControllerProvider.notifier).reload();
    return date;
  }

  Future<DateView> submit(
    String dateId, {
    required String photoId,
    String? caption,
  }) async {
    final date = await _repository.submit(
      dateId,
      photoId: photoId,
      caption: caption,
    );
    _ref.invalidate(dateDetailProvider(dateId));
    await _ref.read(meControllerProvider.notifier).reload();
    return date;
  }
}

String participantStatusLabel(ParticipantStatus status) => switch (status) {
      ParticipantStatus.assigned => '아직 주제 확인 전',
      ParticipantStatus.joined => '촬영 중',
      ParticipantStatus.submitted => '제출 완료',
    };
