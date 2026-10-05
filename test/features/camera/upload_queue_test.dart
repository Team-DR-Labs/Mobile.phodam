import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phodam/core/network/api_error.dart';
import 'package:phodam/core/time/clock.dart';
import 'package:phodam/features/camera/data/models/photo_models.dart';
import 'package:phodam/features/camera/data/models/queued_photo.dart';
import 'package:phodam/features/camera/data/photo_repository.dart';
import 'package:phodam/features/camera/data/photo_transfer.dart';
import 'package:phodam/features/camera/data/upload_queue.dart';
import 'package:phodam/features/camera/data/upload_queue_store.dart';

import '../../helpers/fixtures.dart';

class MockPhotoRepository extends Mock implements PhotoRepository {}

class MockPhotoTransfer extends Mock implements PhotoTransfer {}

void main() {
  late Directory dir;
  late MockPhotoRepository repository;
  late MockPhotoTransfer transfer;
  late UploadQueueStore store;
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

  Future<List<QueuedPhoto>> addAndProcess(
    ProviderContainer container,
    ShotReservation r,
  ) async {
    final queue = container.read(uploadQueueProvider.notifier);
    await queue.add(r, jpeg);
    await queue.process();
    return container.read(uploadQueueProvider).requireValue;
  }

  test('presigned PUT 후 complete 하면 uploaded 가 되고 파일은 남는다', () async {
    final container = createContainer();

    final items = await addAndProcess(container, reservation('p1'));

    expect(items.single.status, QueueStatus.uploaded);
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

  test('네트워크 오류면 큐에 남기고 다음 process 에서 다시 시도한다', () async {
    var fail = true;
    when(() => transfer.upload(any(), any())).thenAnswer((_) async {
      if (fail) throw const ApiException(ApiErrorCode.network);
    });
    final container = createContainer();

    var items = await addAndProcess(container, reservation('p1'));
    expect(items.single.status, QueueStatus.pending);
    expect(items.single.attempts, 1);

    fail = false;
    await container.read(uploadQueueProvider.notifier).process();
    items = container.read(uploadQueueProvider).requireValue;
    expect(items.single.status, QueueStatus.uploaded);
  });

  test('데이트가 끝나 올릴 수 없으면 큐와 파일을 정리한다', () async {
    when(() => repository.complete('p1'))
        .thenThrow(const ApiException(ApiErrorCode.dateNotActive));
    final container = createContainer();

    final items = await addAndProcess(container, reservation('p1'));

    expect(items, isEmpty);
    expect(dir.listSync().whereType<File>().where((f) => f.path.endsWith('.jpg')),
        isEmpty);
  });

  test('PHOTO_NOT_UPLOADED 면 URL 을 비워 다음에 새로 올린다', () async {
    when(() => repository.complete('p1'))
        .thenThrow(const ApiException(ApiErrorCode.photoNotUploaded));
    final container = createContainer();

    final items = await addAndProcess(container, reservation('p1'));

    expect(items.single.status, QueueStatus.pending);
    expect(items.single.target, isNull);
  });

  test('보관 기간이 지난 로컬 사진은 시작할 때 지운다', () async {
    final container = createContainer();
    await addAndProcess(container, reservation('p1'));
    container.dispose();

    now = t0.add(const Duration(days: 12));
    final next = createContainer();
    final items = await next.read(uploadQueueProvider.future);

    expect(items, isEmpty);
  });

  test('remove 는 로컬 파일과 항목을 지운다', () async {
    final container = createContainer();
    final items = await addAndProcess(container, reservation('p1'));

    await container.read(uploadQueueProvider.notifier).remove('p1');

    expect(container.read(uploadQueueProvider).requireValue, isEmpty);
    expect(File(items.single.filePath).existsSync(), isFalse);
  });
}
