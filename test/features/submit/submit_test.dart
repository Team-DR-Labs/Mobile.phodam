import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phodam/features/camera/data/models/photo_models.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phodam/features/camera/data/models/queued_photo.dart';
import 'package:phodam/features/camera/data/photo_repository.dart';
import 'package:phodam/features/camera/data/upload_queue.dart';
import 'package:phodam/features/submit/presentation/caption_field.dart';
import 'package:phodam/features/submit/presentation/submit_page.dart';
import 'package:phodam/features/submit/presentation/submit_photos.dart';

import '../../helpers/fixtures.dart';

void main() {
  group('mergeSelectable', () {
    test('서버에 uploaded 인 사진만 고를 수 있고 로컬 파일을 우선 쓴다', () {
      final local = [
        QueuedPhoto(
          photoId: 'p1',
          dateId: 'd1',
          userId: 'u-alice',
          filePath: '/q/p1.jpg',
          status: QueueStatus.uploaded,
          createdAt: t0,
        ),
        QueuedPhoto(
          photoId: 'p2',
          dateId: 'd1',
          userId: 'u-alice',
          filePath: '/q/p2.jpg',
          status: QueueStatus.pending,
          createdAt: t0.add(const Duration(minutes: 1)),
        ),
      ];

      final merged = mergeSelectable([photoWithUrl('p1')], local);

      expect(merged.map((p) => p.photoId), ['p1', 'p2']);
      expect(merged[0].uploaded, isTrue);
      expect(merged[0].localPath, '/q/p1.jpg');
      expect(merged[1].uploaded, isFalse);
    });

    test('reserved 등 다른 상태는 후보에서 뺀다', () {
      final merged = mergeSelectable(
        [photoWithUrl('p1', status: PhotoStatus.reserved)],
        const [],
      );
      expect(merged, isEmpty);
    });
  });

  test('큐의 업로드 완료 목록이 바뀔 때만 my-photos 를 다시 부른다', () async {
    final repository = MockPhotoRepository();
    when(() => repository.myPhotos('d1')).thenAnswer((_) async => const []);
    final queue = _SettableQueue();
    final container = ProviderContainer.test(
      overrides: [
        photoRepositoryProvider.overrideWithValue(repository),
        uploadQueueProvider.overrideWith(() => queue),
      ],
    );
    container.listen(selectablePhotosProvider('d1'), (_, _) {});
    QueuedPhoto item(String id, QueueStatus status, {int attempts = 0}) =>
        QueuedPhoto(
          photoId: id,
          dateId: 'd1',
          userId: 'u-alice',
          filePath: '/q/$id.jpg',
          status: status,
          createdAt: t0,
          attempts: attempts,
        );

    await container.read(selectablePhotosProvider('d1').future);
    queue.set([item('p1', QueueStatus.pending)]);
    await container.read(selectablePhotosProvider('d1').future);
    queue.set([item('p1', QueueStatus.pending, attempts: 1)]);
    final pending = await container.read(selectablePhotosProvider('d1').future);
    expect(pending.single.uploaded, isFalse);
    verify(() => repository.myPhotos('d1')).called(1);

    queue.set([item('p1', QueueStatus.uploaded)]);
    await container.read(selectablePhotosProvider('d1').future);
    verify(() => repository.myPhotos('d1')).called(1);
  });

  test('글자 수는 앞뒤 공백을 빼고 rune 으로 센다', () {
    expect(captionLength('  안녕  '), 2);
    expect(captionLength('👍'), 1);
    expect(normalizeCaption('   '), isNull);
    expect(normalizeCaption(' 좋아 '), '좋아');
  });

  group('RuneLimitFormatter', () {
    const formatter = RuneLimitFormatter(5);

    test('앞뒤 공백은 세지 않는다(카운터와 같은 기준)', () {
      final result = formatter.formatEditUpdate(
          _value('  abcd'), _value('  abcde  '));
      expect(result.text, '  abcde  ');
    });

    test('넘치는 붙여넣기는 들어갈 만큼만 잘라 넣는다', () {
      final result = formatter.formatEditUpdate(_value('ab'), _value('ab👍👍👍👍'));
      expect(result.text, 'ab👍👍👍');
      expect(captionLength(result.text), 5);
      expect(result.selection.baseOffset, result.text.length);
    });

    test('가운데 붙여넣기는 뒤쪽 기존 글을 지우지 않는다', () {
      final result = formatter.formatEditUpdate(
          _value('ae', 1), _value('abcdxyze', 7));
      expect(result.text, 'abcde');
      expect(result.selection.baseOffset, 4);
    });
  });

  group('SubmitPage', () {
    Future<void> pump(WidgetTester tester, List<SelectablePhoto> photos) async {
      tester.view
        ..physicalSize = const Size(800, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectablePhotosProvider('d1').overrideWith((ref) async => photos),
            uploadQueueProvider.overrideWith(_IdleQueue.new),
          ],
          child: const MaterialApp(home: SubmitPage(dateId: 'd1')),
        ),
      );
      await tester.pump();
    }

    final photos = [
      SelectablePhoto(photoId: 'p1', createdAt: t0, uploaded: true),
      SelectablePhoto(photoId: 'p2', createdAt: t0, uploaded: false),
    ];

    testWidgets('제출 전 사진에는 저장·공유·다운로드 UI 가 없다', (tester) async {
      await pump(tester, photos);

      for (final icon in [
        Icons.download,
        Icons.download_outlined,
        Icons.save_alt,
        Icons.share,
        Icons.ios_share,
      ]) {
        expect(find.byIcon(icon), findsNothing);
      }
      expect(find.textContaining('저장'), findsNothing);
      expect(find.textContaining('공유'), findsNothing);
      expect(find.textContaining('다운로드'), findsNothing);
    });

    testWidgets('업로드 중인 사진은 고를 수 없고, 고르기 전에는 제출할 수 없다',
        (tester) async {
      await pump(tester, photos);
      FilledButton submit() =>
          tester.widget<FilledButton>(find.byKey(const Key('submitButton')));

      expect(find.text('업로드 중'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pick-p2')));
      await tester.pump();
      expect(submit().onPressed, isNull);

      await tester.tap(find.byKey(const Key('pick-p1')));
      await tester.pump();
      expect(submit().onPressed, isNotNull);
    });

    testWidgets('제출하면 수정할 수 없다는 확인을 받는다', (tester) async {
      await pump(tester, photos);
      await tester.tap(find.byKey(const Key('pick-p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('submitButton')));
      await tester.pumpAndSettle();

      expect(find.text('제출 후 수정할 수 없어요.'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
    });

    testWidgets('글은 200자(rune)까지만 입력된다', (tester) async {
      await pump(tester, photos);
      await tester.enterText(
          find.byKey(const Key('captionField')), '가' * 250);
      await tester.pump();

      final field = tester.widget<TextField>(find.byKey(const Key('captionField')));
      expect(field.controller!.text.runes.length, lessThanOrEqualTo(200));
    });
  });
}

class _IdleQueue extends UploadQueue {
  @override
  Future<List<QueuedPhoto>> build() async => const [];

  @override
  Future<void> process({bool force = false}) async {}
}

class MockPhotoRepository extends Mock implements PhotoRepository {}

class _SettableQueue extends UploadQueue {
  @override
  Future<List<QueuedPhoto>> build() async => const [];

  void set(List<QueuedPhoto> items) => state = AsyncData(items);

  @override
  Future<void> process({bool force = false}) async {}
}

TextEditingValue _value(String text, [int? cursor]) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor ?? text.length),
    );
