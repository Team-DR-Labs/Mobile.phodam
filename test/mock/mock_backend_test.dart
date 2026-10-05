import 'dart:io';

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
