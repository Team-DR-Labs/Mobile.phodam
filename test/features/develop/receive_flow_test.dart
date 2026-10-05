import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phodam/features/camera/data/models/photo_models.dart';
import 'package:phodam/features/camera/data/photo_repository.dart';
import 'package:phodam/features/camera/data/photo_transfer.dart';
import 'package:phodam/features/camera/data/upload_queue_store.dart';
import 'package:phodam/features/develop/data/gallery_saver.dart';
import 'package:phodam/features/develop/data/receive_service.dart';
import 'package:phodam/features/develop/presentation/receive_controller.dart';

import '../../helpers/fixtures.dart';

class MockPhotoRepository extends Mock implements PhotoRepository {}

class MockPhotoTransfer extends Mock implements PhotoTransfer {}

class MockGallerySaver extends Mock implements GallerySaver {}

/// overrideWithValue 로 우회하지 않고 실제 receiveServiceProvider 경로로 받는다.
void main() {
  late Directory dir;
  late MockPhotoRepository repository;
  late MockPhotoTransfer transfer;
  late MockGallerySaver gallery;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('receive_flow_test');
    repository = MockPhotoRepository();
    transfer = MockPhotoTransfer();
    gallery = MockGallerySaver();
    when(() => repository.receivable('d1')).thenAnswer(
      (_) async => Receivable(
        receiveDeadlineAt: t0.add(const Duration(days: 7)),
        items: [photoWithUrl('p1'), photoWithUrl('p2'), photoWithUrl('p3')],
      ),
    );
    when(() => repository.ackReceived(any()))
        .thenAnswer((i) async => photo(i.positionalArguments.first as String));
    when(() => transfer.download(any(), any())).thenAnswer(
      (i) async => File(i.positionalArguments[1] as String).writeAsBytes([1]),
    );
    when(() => gallery.ensureAccess()).thenAnswer((_) async => true);
    when(() => gallery.saveImage(any())).thenAnswer((_) async {});
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('전체 받기가 첫 장 이후에도 끝까지 진행된다', () async {
    final container = ProviderContainer.test(
      overrides: [
        photoRepositoryProvider.overrideWithValue(repository),
        photoTransferProvider.overrideWithValue(transfer),
        gallerySaverProvider.overrideWithValue(gallery),
        uploadQueueStoreProvider.overrideWithValue(
          UploadQueueStore(() async => Directory('${dir.path}/queue')),
        ),
        receiveTempDirProvider.overrideWithValue(() async => dir),
      ],
    );
    container.listen(receiveControllerProvider('d1'), (_, _) {});
    await container.read(receiveControllerProvider('d1').future);

    await container.read(receiveControllerProvider('d1').notifier).receiveAll();

    final items =
        container.read(receiveControllerProvider('d1')).requireValue.items;
    expect(items.map((i) => i.status), everyElement(ReceiveItemStatus.saved));
    verify(() => repository.ackReceived(any())).called(3);
  });

  test('권한 요청 중 두 번 눌러도 한 번만 실행된다', () async {
    when(() => gallery.ensureAccess()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return true;
    });
    final container = ProviderContainer.test(
      overrides: [
        photoRepositoryProvider.overrideWithValue(repository),
        photoTransferProvider.overrideWithValue(transfer),
        gallerySaverProvider.overrideWithValue(gallery),
        uploadQueueStoreProvider.overrideWithValue(
          UploadQueueStore(() async => Directory('${dir.path}/queue')),
        ),
        receiveTempDirProvider.overrideWithValue(() async => dir),
      ],
    );
    container.listen(receiveControllerProvider('d1'), (_, _) {});
    await container.read(receiveControllerProvider('d1').future);
    final controller = container.read(receiveControllerProvider('d1').notifier);

    await Future.wait([controller.receiveAll(), controller.receiveAll()]);

    verify(() => gallery.ensureAccess()).called(1);
    verify(() => repository.ackReceived(any())).called(3);
  });
}
