import 'package:flutter_test/flutter_test.dart';
import 'package:phodam/features/date/data/models/date_models.dart';
import 'package:phodam/features/home/presentation/home_stage.dart';

import '../../helpers/fixtures.dart' as f;

void main() {
  test('진행 중 데이트가 없으면 시작 단계', () {
    expect(homeStageOf(f.me()), HomeStage.noDate);
  });

  test('내 참여 상태에 따라 참여·촬영·제출 단계', () {
    HomeStage stageFor(ParticipantStatus s) =>
        homeStageOf(f.me(current: f.dateView(myStatus: s)));

    expect(stageFor(ParticipantStatus.assigned), HomeStage.needJoin);
    expect(stageFor(ParticipantStatus.joined), HomeStage.shooting);
    expect(stageFor(ParticipantStatus.submitted), HomeStage.submitted);
  });

  test('끝난 데이트는 시작 단계로 본다', () {
    final me = f.me(current: f.dateView(status: DateStatus.expired));
    expect(homeStageOf(me), HomeStage.noDate);
  });
}
