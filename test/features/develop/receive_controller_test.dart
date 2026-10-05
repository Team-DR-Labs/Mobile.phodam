import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phodam/features/camera/data/models/photo_models.dart';
import 'package:phodam/features/camera/data/photo_repository.dart';
import 'package:phodam/features/camera/data/photo_transfer.dart';
import 'package:phodam/features/develop/data/gallery_saver.dart';
import 'package:phodam/features/develop/data/receive_service.dart';
import 'package:phodam/features/develop/presentation/receive_controller.dart';

import '../../helpers/fixtures.dart';

class MockPhotoRepository extends Mock implements PhotoRepository {}

class MockPhotoTransfer extends Mock implements PhotoTransfer {}

class MockGallerySaver extends Mock implements GallerySaver {}

void main() {
  late Directory dir;
  late MockPhotoRepository repository;
  late MockPhotoTransfer transfer;
  late MockGallerySaver gallery;

  final receivable = Receivable(
    receiveDeadlineAt: t0.add(const Duration(days: 7)),
    items: [
      photoWithUrl('rep', status: PhotoStatus.archived, representative: true,
          receivedAt: t0),
      photoWithUrl('p1'),
      photoWithUrl('p2'),
      photoWithUrl('p3'),
    ],
  );

  setUp(() {
    dir = Directory.systemTemp.createTempSync('receive_controller_test');
    repository = MockPhotoRepository();
    transfer = MockPhotoTransfer();
    gallery = MockGallerySaver();
    when(() => repository.receivable('d1')).thenAnswer((_) async => receivable);
    when(() => repository.ackReceived(any()))
        .thenAnswer((i) async => photo(i.positionalArguments.first as String));
    when(() => transfer.download(any(), any())).thenAnswer((i) async {
      final file = File(i.positionalArguments[1] as String);
      return file.writeAsBytes([1]);
    });
    when(() => gallery.ensureAccess()).thenAnswer((_) async => true);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<ProviderContainer> createContainer() async {
    final container = ProviderContainer.test(
      overrides: [
        photoRepositoryProvider.overrideWithValue(repository),
        gallerySaverProvider.overrideWithValue(gallery),
        receiveServiceProvider.overrideWithValue(
          ReceiveService(
            repository: repository,
            transfer: transfer,
            gallery: gallery,
            tempDir: () async => dir,
            onReceived: (_) async {},
          ),
        ),
      ],
    );
    container.listen(receiveControllerProvider('d1'), (_, _) {});
    await container.read(receiveControllerProvider('d1').future);
    return container;
  }

  Map<String, ReceiveItemStatus> statuses(ProviderContainer c) => {
        for (final item
            in c.read(receiveControllerProvider('d1')).requireValue.items)
          item.photo.id: item.status,
      };

  test('이미 받은 대표 사진은 saved 로 시작한다', () async {
    final container = await createContainer();
    expect(statuses(container)['rep'], ReceiveItemStatus.saved);
    expect(statuses(container)['p1'], ReceiveItemStatus.idle);
  });

  test('전체 받기: 저장 성공한 장만 ack 하고 실패 장은 failed 로 남긴다', () async {
    when(() => gallery.saveImage(any())).thenAnswer((i) async {
      final path = i.positionalArguments.first as String;
      if (path.contains('p2')) throw Exception('save failed');
    });
    final container = await createContainer();

    await container.read(receiveControllerProvider('d1').notifier).receiveAll();

    expect(statuses(container), {
      'rep': ReceiveItemStatus.saved,
      'p1': ReceiveItemStatus.saved,
      'p2': ReceiveItemStatus.failed,
      'p3': ReceiveItemStatus.saved,
    });
    verify(() => repository.ackReceived('p1')).called(1);
    verify(() => repository.ackReceived('p3')).called(1);
    verifyNever(() => repository.ackReceived('p2'));
    verifyNever(() => repository.ackReceived('rep'));

    // 실패한 장만 다시 받는다.
    when(() => gallery.saveImage(any())).thenAnswer((_) async {});
    await container.read(receiveControllerProvider('d1').notifier).retry('p2');
    expect(statuses(container)['p2'], ReceiveItemStatus.saved);
    verify(() => repository.ackReceived('p2')).called(1);
  });

  test('선택 받기는 고른 장만 처리한다', () async {
    when(() => gallery.saveImage(any())).thenAnswer((_) async {});
    final container = await createContainer();
    final controller = container.read(receiveControllerProvider('d1').notifier);

    controller.toggleSelect('p3');
    await controller.receiveSelected();

    expect(statuses(container)['p3'], ReceiveItemStatus.saved);
    expect(statuses(container)['p1'], ReceiveItemStatus.idle);
    verifyNever(() => repository.ackReceived('p1'));
  });

  test('사진첩 권한이 없으면 아무것도 받지 않고 안내 상태가 된다', () async {
    when(() => gallery.ensureAccess()).thenAnswer((_) async => false);
    final container = await createContainer();

    await container.read(receiveControllerProvider('d1').notifier).receiveAll();

    final state = container.read(receiveControllerProvider('d1')).requireValue;
    expect(state.permissionDenied, isTrue);
    verifyNever(() => transfer.download(any(), any()));
    verifyNever(() => repository.ackReceived(any()));
  });
}
