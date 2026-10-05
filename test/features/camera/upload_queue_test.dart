import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phodam/core/network/api_error.dart';
import 'package:phodam/core/storage/secure_storage.dart';
import 'package:phodam/core/time/clock.dart';
import 'package:phodam/features/camera/data/models/photo_models.dart';
import 'package:phodam/features/camera/data/models/queued_photo.dart';
import 'package:phodam/features/camera/data/photo_repository.dart';
import 'package:phodam/features/camera/data/photo_transfer.dart';
import 'package:phodam/features/camera/data/upload_queue.dart';
import 'package:phodam/features/camera/data/upload_queue_store.dart';

import '../../helpers/fake_secure_storage.dart';
import '../../helpers/fixtures.dart';

class MockPhotoRepository extends Mock implements PhotoRepository {}

class MockPhotoTransfer extends Mock implements PhotoTransfer {}

void main() {
  late Directory dir;
  late MockPhotoRepository repository;
  late MockPhotoTransfer transfer;
  late UploadQueueStore store;
  late FakeSecureStorage storage;
  var now = t0;

  setUpAll(() {
    registerFallbackValue(uploadTarget());
    registerFallbackValue(File('x'));
  });

  setUp(() {
    dir = Directory.systemTemp.createTempSync('upload_queue_test');
    repository = MockPhotoRepository();
    transfer = MockPhotoTransfer();
    store = UploadQueueStore(() async => dir);
    storage = FakeSecureStorage(userId: 'u-alice');
    now = t0;
    when(() => transfer.upload(any(), any())).thenAnswer((_) async {});
    when(() => repository.complete(any()))
        .thenAnswer((i) async => photo(i.positionalArguments.first as String));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  ProviderContainer createContainer() => ProviderContainer.test(
        overrides: [
          uploadQueueStoreProvider.overrideWithValue(store),
          photoRepositoryProvider.overrideWithValue(repository),
          photoTransferProvider.overrideWithValue(transfer),
          secureStorageProvider.overrideWithValue(storage),
          clockProvider.overrideWithValue(() => now),
        ],
      );

  ShotReservation reservation(String id, {DateTime? expiresAt}) =>
      ShotReservation(
        photo: photo(id, status: PhotoStatus.reserved),
        upload: uploadTarget(expiresAt: expiresAt),
        filmBalance: 23,
      );

  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  UploadQueue queueOf(ProviderContainer c) =>
      c.read(uploadQueueProvider.notifier);

  List<QueuedPhoto> itemsOf(ProviderContainer c) =>
      c.read(uploadQueueProvider).requireValue;

  Future<List<QueuedPhoto>> addAndProcess(
    ProviderContainer container,
    ShotReservation r,
  ) async {
    await queueOf(container).add(r, jpeg);
    await queueOf(container).process();
    return itemsOf(container);
  }

  Iterable<File> jpgFiles() =>
      dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jpg'));

  test('presigned PUT 후 complete 하면 uploaded 가 되고 파일은 남는다', () async {
    final container = createContainer();

    final items = await addAndProcess(container, reservation('p1'));

    expect(items.single.status, QueueStatus.uploaded);
    expect(items.single.userId, 'u-alice');
    expect(File(items.single.filePath).existsSync(), isTrue);
    verify(() => transfer.upload(any(), any())).called(1);
    verify(() => repository.complete('p1')).called(1);
    // 재시작해도 디스크에서 같은 상태를 읽는다.
    final restored = await store.load();
    expect(restored.single.status, QueueStatus.uploaded);
  });

  test('업로드 URL 이 만료됐으면 재발급받아 올린다', () async {
    final fresh = uploadTarget(expiresAt: t0.add(const Duration(hours: 1)));
    when(() => repository.reissueUploadUrl('p1'))
        .thenAnswer((_) async => fresh);
    final container = createContainer();

    final items = await addAndProcess(
      container,
      reservation('p1', expiresAt: t0.subtract(const Duration(minutes: 1))),
    );

    expect(items.single.status, QueueStatus.uploaded);
    verify(() => repository.reissueUploadUrl('p1')).called(1);
    verify(() => transfer.upload(fresh, any())).called(1);
  });

  test('실패하면 백오프로 미루고, 강제 재시도나 시간이 지나면 다시 올린다', () async {
    var fail = true;
    when(() => transfer.upload(any(), any())).thenAnswer((_) async {
      if (fail) throw const ApiException(ApiErrorCode.network);
    });
    final container = createContainer();

    var items = await addAndProcess(container, reservation('p1'));
    expect(items.single.status, QueueStatus.pending);
    expect(items.single.attempts, 1);
    expect(items.single.nextAttemptAt, t0.add(UploadQueue.backoff(1)));

    fail = false;
    await queueOf(container).process();
    expect(itemsOf(container).single.status, QueueStatus.pending,
        reason: '백오프 중에는 자동 재시도하지 않는다');

    now = t0.add(const Duration(seconds: 6));
    await queueOf(container).process();
    items = itemsOf(container);
    expect(items.single.status, QueueStatus.uploaded);
  });

  test('앱 복귀 등 강제 재시도는 백오프를 무시한다', () async {
    var fail = true;
    when(() => transfer.upload(any(), any())).thenAnswer((_) async {
      if (fail) throw const ApiException(ApiErrorCode.network);
    });
    final container = createContainer();
    await addAndProcess(container, reservation('p1'));

    fail = false;
    await queueOf(container).process(force: true);

    expect(itemsOf(container).single.status, QueueStatus.uploaded);
  });

  test('백오프 간격은 2배씩 늘고 30분을 넘지 않는다', () {
    expect(UploadQueue.backoff(1), const Duration(seconds: 5));
    expect(UploadQueue.backoff(2), const Duration(seconds: 10));
    expect(UploadQueue.backoff(20), const Duration(minutes: 30));
  });

  test('데이트가 끝나 올릴 수 없으면 큐와 파일을 정리한다', () async {
    when(() => repository.complete('p1'))
        .thenThrow(const ApiException(ApiErrorCode.dateNotActive));
    final container = createContainer();

    final items = await addAndProcess(container, reservation('p1'));

    expect(items, isEmpty);
    expect(jpgFiles(), isEmpty);
    expect(await store.load(), isEmpty);
  });

  test('PHOTO_NOT_UPLOADED 면 URL 을 비워 다음에 새로 올린다', () async {
    when(() => repository.complete('p1'))
        .thenThrow(const ApiException(ApiErrorCode.photoNotUploaded));
    final container = createContainer();

    final items = await addAndProcess(container, reservation('p1'));

    expect(items.single.status, QueueStatus.pending);
    expect(items.single.target, isNull);
  });

  test('사진 파일이 없으면 업로드하지 않고 큐에서 뺀다(무한 재시도 방지)', () async {
    when(() => transfer.upload(any(), any()))
        .thenThrow(const ApiException(ApiErrorCode.network));
    final container = createContainer();
    final items = await addAndProcess(container, reservation('p1'));
    expect(items.single.status, QueueStatus.pending);
    File(items.single.filePath).deleteSync();
    clearInteractions(transfer);

    await queueOf(container).process(force: true);

    expect(itemsOf(container), isEmpty);
    expect(await store.load(), isEmpty);
    verifyNever(() => transfer.upload(any(), any()));
  });

  test('동시에 여러 장을 넣어도 디스크 목록이 깨지거나 빠지지 않는다', () async {
    final container = createContainer();
    await container.read(uploadQueueProvider.future);

    await Future.wait([
      for (var i = 0; i < 8; i++) queueOf(container).add(reservation('p$i'), jpeg),
    ]);
    await queueOf(container).process();

    final restored = await store.load();
    expect(restored.map((i) => i.photoId).toSet(),
        {for (var i = 0; i < 8; i++) 'p$i'});
    expect(restored.every((i) => i.status == QueueStatus.uploaded), isTrue);
    expect(jpgFiles(), hasLength(8));
  });

  test('항목 파일 하나가 깨져도 나머지는 읽고, 깨진 파일은 보존한다', () async {
    final container = createContainer();
    await addAndProcess(container, reservation('p1'));
    await addAndProcess(container, reservation('p2'));
    File('${dir.path}/p1.json').writeAsStringSync('{broken');

    final restored = await store.load();

    expect(restored.map((i) => i.photoId), ['p2']);
    expect(File('${dir.path}/p1.json${UploadQueueStore.corruptSuffix}')
        .existsSync(), isTrue);
    expect(File('${dir.path}/p1.jpg').existsSync(), isTrue);
  });

  test('처리 중에 추가된 사진도 이어서 올린다', () async {
    final container = createContainer();
    var added = false;
    when(() => repository.complete('p1')).thenAnswer((_) async {
      if (!added) {
        added = true;
        // 마지막 항목을 처리하는 도중 새 사진이 들어온다.
        unawaited(queueOf(container).add(reservation('p2'), jpeg));
      }
      return photo('p1');
    });

    await queueOf(container).add(reservation('p1'), jpeg);
    await queueOf(container).process();
    await pumpEventQueue();
    await queueOf(container).process();

    expect(itemsOf(container).map((i) => i.status),
        everyElement(QueueStatus.uploaded));
    verify(() => repository.complete('p2')).called(1);
  });

  test('다른 계정이 찍은 사진은 처리하지 않고 보존, 원래 계정으로 돌아오면 올린다', () async {
    final container = createContainer();
    when(() => transfer.upload(any(), any()))
        .thenThrow(const ApiException(ApiErrorCode.network));
    await addAndProcess(container, reservation('p1'));
    clearInteractions(transfer);
    when(() => transfer.upload(any(), any())).thenAnswer((_) async {});

    storage.userId = 'u-bob';
    await queueOf(container).process(force: true);
    verifyNever(() => transfer.upload(any(), any()));
    expect(itemsOf(container).single.status, QueueStatus.pending);

    storage.userId = 'u-alice';
    await queueOf(container).process(force: true);
    expect(itemsOf(container).single.status, QueueStatus.uploaded);
  });

  test('보관 기간이 지난 로컬 사진은 시작할 때 지운다', () async {
    final container = createContainer();
    await addAndProcess(container, reservation('p1'));
    container.dispose();

    now = t0.add(const Duration(days: 12));
    final next = createContainer();
    final items = await next.read(uploadQueueProvider.future);

    expect(items, isEmpty);
    expect(jpgFiles(), isEmpty);
  });

  test('remove 는 로컬 파일과 항목을 지운다', () async {
    final container = createContainer();
    final items = await addAndProcess(container, reservation('p1'));

    await queueOf(container).remove('p1');

    expect(itemsOf(container), isEmpty);
    expect(File(items.single.filePath).existsSync(), isFalse);
    expect(await store.load(), isEmpty);
  });
}
