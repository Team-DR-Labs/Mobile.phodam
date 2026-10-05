import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phodam/features/date/data/models/date_models.dart';
import 'package:phodam/features/diary/data/diary_repository.dart';
import 'package:phodam/features/diary/data/models/diary_models.dart';
import 'package:phodam/features/diary/presentation/diary_controller.dart';
import 'package:phodam/features/diary/presentation/diary_detail_page.dart';

import '../../helpers/fixtures.dart';

class MockDiaryRepository extends Mock implements DiaryRepository {}

DiaryListItem item(String id, String localDate) => DiaryListItem(
      dateId: id,
      localDate: localDate,
      theme: const DateTheme(id: 'th', title: '온기'),
      visibility: DiaryVisibility.shared,
      startedAt: t0,
      thumbnailUrl: 'asset:none',
      thumbnailUrlExpiresAt: t0,
    );

DiaryEntry entry(bool isMe) => DiaryEntry(
      author: isMe ? alice : bob,
      isMe: isMe,
      topic: Topic(id: isMe ? 't1' : 't2', title: isMe ? '따뜻한 색' : '편안한 장면'),
      caption: isMe ? '내 글' : '상대 글',
      photoUrl: 'asset:none',
      photoUrlExpiresAt: t0,
      submittedAt: t0,
    );

DiaryDetail detail(DiaryVisibility visibility, List<DiaryEntry> entries) =>
    DiaryDetail(
      dateId: 'd1',
      localDate: '2026-10-05',
      theme: const DateTheme(id: 'th', title: '온기'),
      visibility: visibility,
      startedAt: t0,
      entries: entries,
    );

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  test('local_date 로 묶고 순서를 유지한다', () {
    final groups = groupByLocalDate([
      item('a', '2026-10-05'),
      item('b', '2026-10-05'),
      item('c', '2026-10-01'),
    ]);

    expect(groups.map((g) => g.$1), ['2026-10-05', '2026-10-01']);
    expect(groups.first.$2.map((i) => i.dateId), ['a', 'b']);
  });

  test('loadMore 는 커서로 다음 페이지를 이어 붙이고 끝나면 멈춘다', () async {
    final repository = MockDiaryRepository();
    when(() => repository.list(limit: 20)).thenAnswer(
      (_) async => DiaryList(items: [item('a', '2026-10-05')], nextCursor: 'c1'),
    );
    when(() => repository.list(cursor: 'c1', limit: 20)).thenAnswer(
      (_) async => DiaryList(items: [item('b', '2026-10-01')]),
    );
    final container = ProviderContainer.test(
      overrides: [diaryRepositoryProvider.overrideWithValue(repository)],
    );
    container.listen(diaryListControllerProvider, (_, _) {});
    await container.read(diaryListControllerProvider.future);

    final controller = container.read(diaryListControllerProvider.notifier);
    await controller.loadMore();
    await controller.loadMore();

    final page = container.read(diaryListControllerProvider).requireValue;
    expect(page.items.map((i) => i.dateId), ['a', 'b']);
    expect(page.nextCursor, isNull);
    verify(() => repository.list(cursor: 'c1', limit: 20)).called(1);
  });

  group('DiaryDetailPage', () {
    Future<void> pump(WidgetTester tester, DiaryDetail value) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            diaryDetailProvider('d1').overrideWith((ref) async => value),
          ],
          child: const MaterialApp(home: DiaryDetailPage(dateId: 'd1')),
        ),
      );
      await tester.pump();
    }

    testWidgets('공동 공개면 두 사람의 사진·글·주제를 나란히 보여준다', (tester) async {
      await pump(tester,
          detail(DiaryVisibility.shared, [entry(true), entry(false)]));

      expect(find.byType(DiaryEntryCard), findsNWidgets(2));
      expect(find.text('상대 글'), findsOneWidget);
      expect(find.text('편안한 장면'), findsOneWidget);
      expect(find.text('함께 공개'), findsOneWidget);
    });

    testWidgets('공개 전이면 내 기록만 보여준다', (tester) async {
      await pump(tester,
          detail(DiaryVisibility.waiting, [entry(true), entry(false)]));

      expect(find.byType(DiaryEntryCard), findsOneWidget);
      expect(find.text('내 글'), findsOneWidget);
      expect(find.text('상대 글'), findsNothing);
      expect(find.text('편안한 장면'), findsNothing);
    });
  });
}
