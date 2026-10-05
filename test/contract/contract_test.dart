@Tags(['contract'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:phodam/core/network/api_error.dart';
import 'package:phodam/features/auth/presentation/auth_controller.dart';
import 'package:phodam/features/camera/data/film_look.dart';
import 'package:phodam/features/camera/data/models/photo_models.dart';
import 'package:phodam/features/camera/data/models/queued_photo.dart';
import 'package:phodam/features/camera/data/photo_transfer.dart';
import 'package:phodam/features/camera/data/upload_queue.dart';
import 'package:phodam/features/date/data/models/date_models.dart';
import 'package:phodam/features/develop/data/gallery_saver.dart';
import 'package:phodam/features/develop/data/receive_service.dart';
import 'package:phodam/features/diary/data/models/diary_models.dart';

import 'contract_client.dart';

/// 앱 ↔ 로컬 실서버 계약 테스트. 시나리오가 이어지므로 순서대로 실행된다.
///
/// 실행: flutter test --tags contract --run-skipped
void main() {
  final runId = DateTime.now().millisecondsSinceEpoch;
  late ContractClient a;
  late ContractClient b;
  late String dateId;
  late List<String> aPhotoIds;
  late String aRepresentative;

  Matcher apiError(ApiErrorCode code) =>
      throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

  /// 앱 카메라 경로와 같은 처리(색감·그레인·JPEG q85)를 거친 작은 사진.
  Uint8List sampleJpeg(int seed) {
    final source = img.Image(width: 320, height: 240)
      ..clear(img.ColorRgb8(90 + seed * 20, 120, 160));
    return processFilmImage(img.encodePng(source), seed: seed);
  }

  /// 셔터 → 업로드 큐(presigned PUT → complete) 를 앱 코드 그대로 수행한다.
  ///
  /// [expireUrl] 이면 업로드 URL 을 만료된 것으로 바꿔 큐의 재발급 경로를 탄다.
  Future<String> shoot(
    ContractClient client,
    int seed, {
    bool expireUrl = false,
  }) async {
    final reserved = await client.photos.reserveShot(dateId);
    final reservation = expireUrl
        ? reserved.copyWith(
            upload: reserved.upload.copyWith(
              expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
            ),
          )
        : reserved;
    expect(reservation.photo.status, PhotoStatus.reserved);
    expect(reservation.upload.method, 'PUT');
    final queue = client.container.read(uploadQueueProvider.notifier);
    await queue.add(reservation, sampleJpeg(seed));
    await queue.process();
    final item = client.container
        .read(uploadQueueProvider)
        .requireValue
        .byId(reservation.photo.id);
    expect(item?.status, QueueStatus.uploaded, reason: '업로드·complete 성공');
    return reservation.photo.id;
  }

  setUpAll(() {
    a = ContractClient('a');
    b = ContractClient('b');
  });

  tearDownAll(() {
    a.dispose();
    b.dispose();
  });

  test('A·B 개발용 로그인 후 /me 파싱(필름 24장, 커플 없음)', () async {
    await a.auth.signInWithDev('contract-a-$runId', nickname: '계약A');
    await b.auth.signInWithDev('contract-b-$runId', nickname: '계약B');
    expect(a.container.read(authControllerProvider), AuthStatus.signedIn);

    final meA = await a.me.getMe();
    expect(meA.user.nickname, '계약A');
    expect(meA.filmBalance, 24);
    expect(meA.couple, isNull);
    expect(meA.currentDate, isNull);
    await expectLater(a.dates.startDate(), apiError(ApiErrorCode.coupleRequired));
  });

  test('A 초대 코드 발급, B 가 입력해 연결', () async {
    final invite = await a.couple.createInvite();
    expect(invite.code, matches(RegExp(r'^[A-HJKMNP-Z2-9]{8}$')));
    expect(invite.expiresAt.isAfter(DateTime.now()), isTrue);

    await expectLater(a.couple.join(invite.code), apiError(ApiErrorCode.inviteInvalid));
    final couple = await b.couple.join(invite.code.toLowerCase());
    expect(couple.partner.nickname, '계약A');
    expect((await a.me.getMe()).couple?.partner.nickname, '계약B');
  });

  test('A 데이트 시작: 내 주제 있음, 상대 주제 null, 중복 시작 불가', () async {
    final date = await a.dates.startDate();
    dateId = date.id;
    expect(date.status, DateStatus.inProgress);
    expect(date.startedByMe, isTrue);
    expect(date.me.status, ParticipantStatus.joined);
    expect(date.me.topic, isNotNull);
    expect(date.partner.topic, isNull);
    expect(date.deadlineAt.difference(date.startedAt), const Duration(hours: 72));

    await expectLater(
        a.dates.startDate(), apiError(ApiErrorCode.dateAlreadyInProgress));
  });

  test('B /me 에서 assigned 확인 후 참여(멱등), 서로 주제는 다르고 비공개', () async {
    final current = (await b.me.getMe()).currentDate!;
    expect(current.id, dateId);
    expect(current.startedByMe, isFalse);
    expect(current.me.status, ParticipantStatus.assigned);
    expect(current.me.topic, isNull);
    expect(current.partner.topic, isNull);
    await expectLater(
        b.photos.reserveShot(dateId), apiError(ApiErrorCode.dateNotJoined));

    final joined = await b.dates.joinDate(dateId);
    expect(joined.me.status, ParticipantStatus.joined);
    expect(joined.partner.topic, isNull);
    expect((await b.dates.joinDate(dateId)).me.topic, joined.me.topic);
    final aView = await a.dates.getDate(dateId);
    expect(aView.me.topic, isNot(joined.me.topic));
    expect(aView.partner.status, ParticipantStatus.joined);
    expect(aView.partner.topic, isNull);
  });

  test('A 샷 3장: 예약·presigned PUT·complete, my-photos 파싱', () async {
    aPhotoIds = [for (var i = 0; i < 3; i++) await shoot(a, i)];

    expect((await a.me.getMe()).filmBalance, 21);
    expect((await a.dates.getDate(dateId)).me.shotCount, 3);
    final mine = await a.photos.myPhotos(dateId);
    expect(mine.map((p) => p.id), unorderedEquals(aPhotoIds));
    expect(mine.every((p) => p.status == PhotoStatus.uploaded), isTrue);
    // 미리보기 URL 이 실제로 열린다.
    final response = await Dio().get<List<int>>(
      mine.first.url,
      options: Options(responseType: ResponseType.bytes),
    );
    expect(response.statusCode, 200);
    expect(response.data!.take(2), [0xFF, 0xD8]);
  });

  test('A 제출(글 포함), 재제출·추가 촬영은 ALREADY_SUBMITTED', () async {
    aRepresentative = aPhotoIds.first;
    final submitted = await a.dates.submit(
      dateId,
      photoId: aRepresentative,
      caption: '  계약 테스트 글  ',
    );
    expect(submitted.me.status, ParticipantStatus.submitted);
    expect(submitted.status, DateStatus.inProgress);
    expect(submitted.me.receiveDeadlineAt,
        submitted.me.submittedAt!.add(const Duration(days: 7)));

    await expectLater(
      a.dates.submit(dateId, photoId: aPhotoIds[1]),
      apiError(ApiErrorCode.alreadySubmitted),
    );
    await expectLater(
        a.photos.reserveShot(dateId), apiError(ApiErrorCode.alreadySubmitted));
  });

  test('A receivable 파싱, 1장 수령(다운로드 → 저장 → ack) 후 목록에서 빠짐', () async {
    final receivable = await a.photos.receivable(dateId);
    expect(receivable.items.map((p) => p.id), unorderedEquals(aPhotoIds));
    final rep = receivable.items.singleWhere((p) => p.isRepresentative);
    expect(rep.id, aRepresentative);
    expect(rep.status, PhotoStatus.archived);

    final target = receivable.items.firstWhere((p) => !p.isRepresentative);
    final saved = <String>[];
    final service = ReceiveService(
      repository: a.photos,
      transfer: a.container.read(photoTransferProvider),
      gallery: _RecordingGallery(saved),
      tempDir: () async => a.queueDir,
      onReceived: (id) =>
          a.container.read(uploadQueueProvider.notifier).remove(id),
    );
    expect(await service.receive(target), ReceiveOutcome.saved);
    expect(saved, hasLength(1));
    expect(
      a.container.read(uploadQueueProvider).requireValue.byId(target.id),
      isNull,
      reason: '수령 후 로컬 큐 파일 정리',
    );

    final after = await a.photos.receivable(dateId);
    expect(after.items.map((p) => p.id), isNot(contains(target.id)));
    // 대표 사진 ack 는 상태를 archived 로 유지한다.
    expect((await a.photos.ackReceived(aRepresentative)).status,
        PhotoStatus.archived);
    expect((await a.photos.ackReceived(target.id)).status, PhotoStatus.received,
        reason: '멱등');
  });

  test('공개 전: A 는 waiting, B 는 A 일기를 볼 수 없다', () async {
    final listA = await a.diaries.list();
    expect(listA.items.single.visibility, DiaryVisibility.waiting);
    final detailA = await a.diaries.detail(dateId);
    expect(detailA.entries.single.isMe, isTrue);
    expect(detailA.entries.single.caption, '계약 테스트 글');

    expect((await b.diaries.list()).items, isEmpty);
    await expectLater(b.diaries.detail(dateId), apiError(ApiErrorCode.notFound));
    expect((await b.dates.getDate(dateId)).partner.topic, isNull);
    await expectLater(
        b.photos.receivable(dateId), apiError(ApiErrorCode.receiveNotAvailable));
  });

  test('B 업로드 예외 경로: 업로드 전 complete, 만료 URL 재발급, 업로드 후 재발급', () async {
    final reserved = await b.photos.reserveShot(dateId);
    await expectLater(b.photos.complete(reserved.photo.id),
        apiError(ApiErrorCode.photoNotUploaded));
    final reissued = await b.photos.reissueUploadUrl(reserved.photo.id);
    expect(reissued.expiresAt.isAfter(DateTime.now()), isTrue);

    final uploaded = await shoot(b, 5, expireUrl: true);
    await expectLater(
        b.photos.reissueUploadUrl(uploaded), apiError(ApiErrorCode.notFound));
    expect((await b.photos.complete(uploaded)).status, PhotoStatus.uploaded,
        reason: 'complete 멱등');
    // 남의 사진은 존재 여부를 숨기고 NOT_FOUND.
    await expectLater(
        b.photos.ackReceived(aPhotoIds[1]), apiError(ApiErrorCode.notFound));
  });

  test('B 샷 1장 + 제출 → revealed, 상대 주제 공개', () async {
    final photoId = await shoot(b, 7);
    final revealed = await b.dates.submit(dateId, photoId: photoId);
    expect(revealed.status, DateStatus.revealed);
    expect(revealed.revealedAt, isNotNull);
    expect(revealed.partner.topic, isNotNull);
    expect((await a.dates.getDate(dateId)).partner.topic, isNotNull);
    expect((await a.me.getMe()).currentDate, isNull);
  });

  test('양쪽 일기 목록·상세(2 entries, 내 것 먼저) 파싱', () async {
    for (final (client, myName) in [(a, '계약A'), (b, '계약B')]) {
      final list = await client.diaries.list(limit: 50);
      final item = list.items.single;
      expect(item.dateId, dateId);
      expect(item.visibility, DiaryVisibility.shared);
      expect(item.localDate, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(list.nextCursor, isNull);

      final detail = await client.diaries.detail(dateId);
      expect(detail.visibility, DiaryVisibility.shared);
      expect(detail.entries, hasLength(2));
      expect(detail.entries.first.isMe, isTrue);
      expect(detail.entries.first.author.nickname, myName);
      expect(detail.entries.last.isMe, isFalse);
    }
    final fromB = await b.diaries.detail(dateId);
    expect(fromB.entries.last.caption, '계약 테스트 글');
    expect(fromB.entries.first.caption, isNull, reason: '글 없이 제출');
  });

  test('401 이면 인터셉터가 리프레시 토큰을 회전하고 재시도한다', () async {
    final oldRefresh = a.storage.refreshToken!;
    a.storage.accessToken = 'invalid-access-token';

    final me = await a.me.getMe();

    expect(me.user.nickname, '계약A');
    expect(a.storage.refreshToken, isNot(oldRefresh));
    expect(a.storage.accessToken, isNot('invalid-access-token'));
    expect(a.sessionExpiredCount, 0);
    // 회전된 이전 리프레시 토큰은 폐기된다.
    final reuse = Dio(BaseOptions(baseUrl: contractBaseUrl));
    await expectLater(
      guardApi(() => reuse.post<void>('/auth/refresh',
          data: {'refresh_token': oldRefresh})),
      apiError(ApiErrorCode.authInvalidRefreshToken),
    );
  });

  test('리프레시까지 무효면 세션 만료로 로그아웃된다', () async {
    b.storage
      ..accessToken = 'invalid-access-token'
      ..refreshToken = 'invalid-refresh-token';

    await expectLater(b.me.getMe(), apiError(ApiErrorCode.unauthorized));
    await pumpEventQueue();

    expect(b.sessionExpiredCount, 1);
    expect(b.container.read(authControllerProvider), AuthStatus.signedOut);
  });

  test('로그아웃 후 이전 리프레시 토큰은 쓸 수 없다', () async {
    final refresh = a.storage.refreshToken!;
    await a.auth.signOut();
    expect(a.storage.refreshToken, isNull);
    await expectLater(
      guardApi(() => Dio(BaseOptions(baseUrl: contractBaseUrl))
          .post<void>('/auth/refresh', data: {'refresh_token': refresh})),
      apiError(ApiErrorCode.authInvalidRefreshToken),
    );
  });
}

class _RecordingGallery implements GallerySaver {
  _RecordingGallery(this.saved);

  final List<String> saved;

  @override
  Future<bool> ensureAccess() async => true;

  @override
  Future<void> saveImage(String path) async {
    final bytes = File(path).readAsBytesSync();
    expect(bytes.take(2), [0xFF, 0xD8], reason: '내려받은 파일이 JPEG');
    saved.add(path);
  }
}
