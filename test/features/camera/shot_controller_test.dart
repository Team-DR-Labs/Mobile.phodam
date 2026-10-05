import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phodam/core/network/api_error.dart';
import 'package:phodam/features/camera/data/film_look.dart';
import 'package:phodam/features/camera/data/models/photo_models.dart';
import 'package:phodam/features/camera/data/photo_repository.dart';
import 'package:phodam/features/camera/data/upload_queue.dart';
import 'package:phodam/features/camera/presentation/shot_controller.dart';
import 'package:phodam/features/me/data/models/me.dart';
import 'package:phodam/features/me/presentation/me_controller.dart';

import '../../helpers/fixtures.dart';

class MockPhotoRepository extends Mock implements PhotoRepository {}

class FakeUploadQueue extends UploadQueue {
  final added = <String>[];

  @override
  Future<List<Never>> build() async => const [];

  @override
  Future<void> add(ShotReservation reservation, Uint8List jpeg) async {
    added.add(reservation.photo.id);
  }
}

class FakeMeController extends MeController {
  @override
  Future<Me?> build() async => me(film: 5);
}

void main() {
  late MockPhotoRepository repository;
  late FakeUploadQueue queue;
  final raw = Uint8List.fromList([1, 2, 3]);

  setUp(() {
    repository = MockPhotoRepository();
    queue = FakeUploadQueue();
  });

  Future<ProviderContainer> createContainer() async {
    final container = ProviderContainer.test(
      overrides: [
        photoRepositoryProvider.overrideWithValue(repository),
        uploadQueueProvider.overrideWith(() => queue),
        meControllerProvider.overrideWith(FakeMeController.new),
        filmProcessorProvider.overrideWithValue((bytes) async => bytes),
      ],
    );
    await container.read(meControllerProvider.future);
    return container;
  }

  ShotReservation reservation(int balance) => ShotReservation(
        photo: photo('p1', status: PhotoStatus.reserved),
        upload: uploadTarget(),
        filmBalance: balance,
      );

  test('촬영과 샷 예약을 동시에 시작하고 큐에 넣는다', () async {
    final reserve = Completer<ShotReservation>();
    final capture = Completer<Uint8List>();
    when(() => repository.reserveShot('d1')).thenAnswer((_) => reserve.future);
    final container = await createContainer();
    var captureStarted = false;

    final result = container
        .read(shotControllerProvider('d1').notifier)
        .shoot(() {
      captureStarted = true;
      return capture.future;
    });
    expect(captureStarted, isTrue, reason: '예약 응답을 기다리지 않고 촬영한다');
    verify(() => repository.reserveShot('d1')).called(1);
    expect(container.read(shotControllerProvider('d1')), isTrue);

    reserve.complete(reservation(4));
    capture.complete(raw);

    expect(await result, isA<ShotSaved>());
    expect(queue.added, ['p1']);
    expect(container.read(meControllerProvider).value?.filmBalance, 4);
    expect(container.read(shotControllerProvider('d1')), isFalse);
  });

  test('FILM_EXHAUSTED 면 잔량을 0 으로 맞추고 큐에 넣지 않는다', () async {
    when(() => repository.reserveShot('d1'))
        .thenThrow(const ApiException(ApiErrorCode.filmExhausted));
    final container = await createContainer();

    final result = await container
        .read(shotControllerProvider('d1').notifier)
        .shoot(() async => raw);

    expect(result, isA<ShotRejected>());
    expect((result as ShotRejected).dateClosed, isFalse);
    expect(container.read(meControllerProvider).value?.filmBalance, 0);
    expect(queue.added, isEmpty);
  });

  test('ALREADY_SUBMITTED, DATE_NOT_ACTIVE 는 데이트 종료로 본다', () async {
    for (final code in [
      ApiErrorCode.alreadySubmitted,
      ApiErrorCode.dateNotActive,
    ]) {
      when(() => repository.reserveShot('d1')).thenThrow(ApiException(code));
      final container = await createContainer();

      final result = await container
          .read(shotControllerProvider('d1').notifier)
          .shoot(() async => raw);

      expect((result as ShotRejected).dateClosed, isTrue);
    }
  });

  test('예약 후 촬영이 실패해도 차감된 잔량을 반영한다', () async {
    when(() => repository.reserveShot('d1'))
        .thenAnswer((_) async => reservation(4));
    final container = await createContainer();

    final result = await container
        .read(shotControllerProvider('d1').notifier)
        .shoot(() async => throw Exception('camera'));

    expect(result, isA<ShotCaptureFailed>());
    expect(container.read(meControllerProvider).value?.filmBalance, 4);
    expect(queue.added, isEmpty);
  });
}
