import '../../date/data/models/date_models.dart';
import '../../me/data/models/me.dart';

/// 홈에서 보여줄 단계.
enum HomeStage {
  /// 진행 중 데이트 없음 → 시작.
  noDate,

  /// 상대가 시작했고 내가 아직 주제를 확인하지 않음 → 참여.
  needJoin,

  /// 주제 확인 완료, 촬영·제출 중.
  shooting,

  /// 내가 제출하고 상대를 기다림.
  submitted,
}

HomeStage homeStageOf(Me me) {
  final date = me.currentDate;
  if (date == null || !date.isActive) return HomeStage.noDate;
  return switch (date.me.status) {
    ParticipantStatus.assigned => HomeStage.needJoin,
    ParticipantStatus.joined => HomeStage.shooting,
    ParticipantStatus.submitted => HomeStage.submitted,
  };
}

String damiMessage(HomeStage stage, Me me) => switch (stage) {
      HomeStage.noDate => me.filmBalance > 0
          ? '오늘은 어떤 장면을 함께 담아 볼까요?'
          : '필름이 다 떨어졌어요. 새 필름을 기다려 주세요.',
      HomeStage.needJoin =>
        '${me.couple?.partner.nickname ?? '상대'}님이 데이트를 시작했어요!\n주제를 확인해 볼까요?',
      HomeStage.shooting => '주제를 떠올리며 천천히 찍어 보세요.',
      HomeStage.submitted => '제출 완료! 현상한 사진을 받아 가세요.',
    };
