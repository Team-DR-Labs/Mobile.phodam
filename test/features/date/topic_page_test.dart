import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phodam/core/time/clock.dart';
import 'package:phodam/features/date/data/models/date_models.dart';
import 'package:phodam/features/date/presentation/date_controller.dart';
import 'package:phodam/features/date/presentation/topic_page.dart';

import '../../helpers/fixtures.dart';

void main() {
  Future<void> pumpTopic(WidgetTester tester, DateView date) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dateDetailProvider('d1').overrideWith((ref) async => date),
          clockProvider.overrideWithValue(() => t0),
        ],
        child: const MaterialApp(home: TopicPage(dateId: 'd1')),
      ),
    );
    await tester.pump();
  }

  testWidgets('내 주제는 보이고 상대 주제는 응답에 있어도 보이지 않는다', (tester) async {
    await pumpTopic(
      tester,
      dateView(
        partnerStatus: ParticipantStatus.joined,
        partnerTopic: const Topic(id: 'secret', title: '상대의 비밀 주제'),
      ),
    );

    expect(find.text('따뜻한 색'), findsOneWidget);
    expect(find.text('상대의 비밀 주제'), findsNothing);
    expect(find.text('촬영 중'), findsOneWidget);
    expect(find.text('촬영하러 가기'), findsOneWidget);
  });

  testWidgets('주제 확인 전이면 참여 버튼만 보인다', (tester) async {
    await pumpTopic(tester, dateView(myStatus: ParticipantStatus.assigned));

    expect(find.text('아직 확인하지 않았어요'), findsOneWidget);
    expect(find.text('참여하고 주제 확인하기'), findsOneWidget);
    expect(find.text('촬영하러 가기'), findsNothing);
  });
}
