import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:phodam/core/network/api_error.dart';
import 'package:phodam/mock/mock_backend.dart';


void main() {
  late MockBackendHarness h;

  setUp(() => h = MockBackendHarness());
  tearDown(() => h.dispose());

  Matcher fails(ApiErrorCode code) =>
      throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

  group('계정·커플', () {
    test('첫 로그인이면 필름 24장을 받는다', () {
      final auth = h.backend.login('alice');
      expect(auth.isNewUser, isTrue);
      expect(h.backend.me().filmBalance, 24);
      expect(h.backend.login('alice').isNewUser, isFalse);
    });

    test('초대 코드로 연결하면 서로의 상대가 된다', () {
      h.backend.login('alice', nickname: '앨리스');
      final invite = h.backend.createInvite();
      expect(invite.code, matches(RegExp(r'^[A-HJKMNP-Z2-9]{8}$')));

      h.backend.login('bob', nickname: '밥');
      final couple = h.backend.joinCouple(invite.code.toLowerCase());

      expect(couple.partner.nickname, '앨리스');
      h.backend.login('alice');
      expect(h.backend.me().couple?.partner.nickname, '밥');
    });

    test('자기 코드, 재발급으로 무효가 된 코드는 쓸 수 없다', () {
      h.backend.login('alice');
      final first = h.backend.createInvite();
      final second = h.backend.createInvite();
      expect(() => h.backend.joinCouple(second.code),
          fails(ApiErrorCode.inviteInvalid));

      h.backend.login('bob');
      expect(() => h.backend.joinCouple(first.code),
          fails(ApiErrorCode.inviteInvalid));
    });

    test('커플이 없으면 데이트를 시작할 수 없다', () {
      h.backend.login('alice');
      expect(h.backend.startDate, fails(ApiErrorCode.coupleRequired));
    });
  });

  group('데이트·촬영', () {
    late String dateId;

    setUp(() {
      h.backend.login('alice', nickname: '앨리스');
      final code = h.backend.createInvite().code;
      h.backend.login('bob', nickname: '밥');
      h.backend.joinCouple(code);
      h.backend.login('alice');
      dateId = h.backend.startDate().id;
    });

    test('시작자는 즉시 주제를 받고 상대는 assigned, 상대 주제는 비공개', () {
      final mine = h.backend.getDate(dateId);
      expect(mine.me.topic, isNotNull);
      expect(mine.partner.topic, isNull);
      expect(mine.deadlineAt.difference(mine.startedAt),
          const Duration(hours: 72));

      h.backend.login('bob');
      final theirs = h.backend.getDate(dateId);
      expect(theirs.me.status.name, 'assigned');
      expect(theirs.me.topic, isNull);
      expect(() => h.backend.reserveShot(dateId),
          fails(ApiErrorCode.dateNotJoined));

      final joined = h.backend.joinDate(dateId);
      expect(joined.me.topic, isNotNull);
      expect(joined.me.topic, isNot(mine.me.topic));
      expect(joined.partner.topic, isNull);
      expect(h.backend.joinDate(dateId).me.topic, joined.me.topic, reason: '멱등');
    });

    test('진행 중 데이트는 하나만', () {
      expect(h.backend.startDate, fails(ApiErrorCode.dateAlreadyInProgress));
    });

    test('셔터마다 필름 1장을 차감하고 0 이면 FILM_EXHAUSTED', () {
      final first = h.backend.reserveShot(dateId);
      expect(first.filmBalance, 23);
      for (var i = 0; i < 23; i++) {
        h.backend.reserveShot(dateId);
      }
      expect(h.backend.me().filmBalance, 0);
      expect(() => h.backend.reserveShot(dateId),
          fails(ApiErrorCode.filmExhausted));
    });

    test('업로드 전 complete 는 PHOTO_NOT_UPLOADED', () async {
      final shot = h.backend.reserveShot(dateId);
      expect(() => h.backend.complete(shot.photo.id),
          fails(ApiErrorCode.photoNotUploaded));
    });

    test('72시간이 지나면 촬영할 수 없고 만료된다', () {
      h.now = h.now.add(const Duration(hours: 72));
      expect(() => h.backend.reserveShot(dateId),
          fails(ApiErrorCode.dateNotActive));
      expect(h.backend.me().currentDate, isNull);
    });
  });

  group('제출·수령·공개', () {
    late String dateId;

    Future<String> shootAndUpload() async {
      final shot = h.backend.reserveShot(dateId);
      await h.backend.storeObject(shot.photo.id, Uint8List.fromList([1, 2]));
      h.backend.complete(shot.photo.id);
      return shot.photo.id;
    }

    setUp(() {
      h.backend.login('alice', nickname: '앨리스');
      final code = h.backend.createInvite().code;
      h.backend.login('bob', nickname: '밥');
      h.backend.joinCouple(code);
      h.backend.login('alice');
      dateId = h.backend.startDate().id;
    });

    test('제출 전에는 수령할 수 없고, 업로드 안 된 사진은 제출할 수 없다', () async {
      expect(() => h.backend.receivable(dateId),
          fails(ApiErrorCode.receiveNotAvailable));
      final reserved = h.backend.reserveShot(dateId).photo.id;
      expect(() => h.backend.submit(dateId, photoId: reserved),
          fails(ApiErrorCode.photoNotUploaded));
    });

    test('제출하면 수정·추가 촬영 불가, 전체 사진 수령 가능, 상대에게는 비공개', () async {
      final rep = await shootAndUpload();
      final other = await shootAndUpload();
      h.backend.reserveShot(dateId); // 업로드하지 않은 샷

      final submitted =
          h.backend.submit(dateId, photoId: rep, caption: '  첫 장  ');
      expect(submitted.me.status.name, 'submitted');
      expect(submitted.me.receiveDeadlineAt,
          submitted.me.submittedAt!.add(const Duration(days: 7)));
      expect(() => h.backend.submit(dateId, photoId: other),
          fails(ApiErrorCode.alreadySubmitted));
      expect(() => h.backend.reserveShot(dateId),
          fails(ApiErrorCode.alreadySubmitted));

      final receivable = h.backend.receivable(dateId);
      expect(receivable.items.map((p) => p.id), unorderedEquals([rep, other]));

      expect(h.backend.diaries().items.single.visibility.name, 'waiting');
      h.backend.login('bob');
      expect(() => h.backend.diary(dateId), fails(ApiErrorCode.notFound));
      expect(h.backend.getDate(dateId).partner.topic, isNull);
    });

    test('비대표 ack 는 received 로 목록에서 빠지고, 대표는 남는다', () async {
      final rep = await shootAndUpload();
      final other = await shootAndUpload();
      h.backend.submit(dateId, photoId: rep);

      expect(h.backend.ackReceived(other).status.name, 'received');
      expect(h.backend.ackReceived(rep).status.name, 'archived');
      expect(h.backend.ackReceived(other).status.name, 'received', reason: '멱등');

      final items = h.backend.receivable(dateId).items;
      expect(items.single.id, rep);
      expect(items.single.receivedAt, isNotNull);
    });

    test('둘 다 제출하면 공동 공개되고 상대 주제·사진·글이 보인다', () async {
      final rep = await shootAndUpload();
      h.backend.submit(dateId, photoId: rep, caption: '앨리스 글');
      h.backend.debugPartnerSubmit();

      final date = h.backend.getDate(dateId);
      expect(date.status.name, 'revealed');
      expect(date.partner.topic, isNotNull);
      final detail = h.backend.diary(dateId);
      expect(detail.visibility.name, 'shared');
      expect(detail.entries.map((e) => e.isMe), [true, false]);
    });

    test('한 명만 제출하고 만료되면 private, 수령 기한은 그대로', () async {
      final rep = await shootAndUpload();
      await shootAndUpload();
      h.backend.submit(dateId, photoId: rep);
      h.now = h.now.add(const Duration(hours: 72));

      expect(h.backend.diary(dateId).visibility.name, 'private');
      expect(h.backend.receivable(dateId).items, hasLength(2));

      h.now = h.now.add(const Duration(days: 7));
      expect(() => h.backend.receivable(dateId),
          fails(ApiErrorCode.receiveNotAvailable));
    });
  });
}

/// 테스트 간 공유하는 저장 디렉터리·시계.
class MockBackendHarness {
  MockBackendHarness() {
    dir = Directory.systemTemp.createTempSync('mock_backend_test');
    backend = MockBackend(
      clock: () => now,
      storageDir: () async => dir,
    );
  }

  late final Directory dir;
  late final MockBackend backend;
  DateTime now = DateTime.utc(2026, 10, 5, 6);

  void dispose() => dir.deleteSync(recursive: true);
}
