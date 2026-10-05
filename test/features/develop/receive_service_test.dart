import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phodam/core/network/api_error.dart';
import 'package:phodam/features/camera/data/photo_repository.dart';
import 'package:phodam/features/camera/data/photo_transfer.dart';
import 'package:phodam/features/develop/data/gallery_saver.dart';
import 'package:phodam/features/develop/data/receive_service.dart';

import '../../helpers/fixtures.dart';

class MockPhotoRepository extends Mock implements PhotoRepository {}

class MockPhotoTransfer extends Mock implements PhotoTransfer {}

class MockGallerySaver extends Mock implements GallerySaver {}

void main() {
  late Directory dir;
  late MockPhotoRepository repository;
  late MockPhotoTransfer transfer;
  late MockGallerySaver gallery;
  late List<String> cleaned;
  late ReceiveService service;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('receive_service_test');
    repository = MockPhotoRepository();
    transfer = MockPhotoTransfer();
    gallery = MockGallerySaver();
    cleaned = [];
    service = ReceiveService(
      repository: repository,
      transfer: transfer,
      gallery: gallery,
      tempDir: () async => dir,
      onReceived: (id) async => cleaned.add(id),
    );
    when(() => transfer.download(any(), any())).thenAnswer((i) async {
      final file = File(i.positionalArguments[1] as String);
      return file.writeAsBytes([1, 2, 3]);
    });
    when(() => repository.ackReceived(any()))
        .thenAnswer((i) async => photo(i.positionalArguments.first as String));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('저장에 성공하면 ack 하고 로컬 파일을 정리한다', () async {
    when(() => gallery.saveImage(any())).thenAnswer((_) async {});

    final outcome = await service.receive(photoWithUrl('p1'));

    expect(outcome, ReceiveOutcome.saved);
    verify(() => repository.ackReceived('p1')).called(1);
    expect(cleaned, ['p1']);
    expect(dir.listSync(), isEmpty, reason: '임시 다운로드 파일은 지운다');
  });

  test('사진첩 저장에 실패한 장은 ack 하지 않는다', () async {
    when(() => gallery.saveImage(any())).thenThrow(Exception('disk full'));

    final outcome = await service.receive(photoWithUrl('p1'));

    expect(outcome, ReceiveOutcome.saveFailed);
    verifyNever(() => repository.ackReceived(any()));
    expect(cleaned, isEmpty);
  });

  test('다운로드에 실패한 장도 ack 하지 않는다', () async {
    when(() => transfer.download(any(), any()))
        .thenThrow(const ApiException(ApiErrorCode.network));

    final outcome = await service.receive(photoWithUrl('p1'));

    expect(outcome, ReceiveOutcome.saveFailed);
    verifyNever(() => gallery.saveImage(any()));
    verifyNever(() => repository.ackReceived(any()));
  });

  test('권한이 거부되면 ack 하지 않고 accessDenied', () async {
    when(() => gallery.saveImage(any()))
        .thenThrow(const GalleryAccessDenied());

    final outcome = await service.receive(photoWithUrl('p1'));

    expect(outcome, ReceiveOutcome.accessDenied);
    verifyNever(() => repository.ackReceived(any()));
  });

  test('저장 후 ack 가 실패하면 ackFailed, 재시도 때는 다시 저장하지 않는다', () async {
    when(() => gallery.saveImage(any())).thenAnswer((_) async {});
    when(() => repository.ackReceived('p1'))
        .thenThrow(const ApiException(ApiErrorCode.network));

    expect(await service.receive(photoWithUrl('p1')), ReceiveOutcome.ackFailed);
    expect(cleaned, isEmpty);

    when(() => repository.ackReceived('p1'))
        .thenAnswer((_) async => photo('p1'));
    final retried = await service.receive(photoWithUrl('p1'), alreadySaved: true);

    expect(retried, ReceiveOutcome.saved);
    verify(() => gallery.saveImage(any())).called(1);
  });

  test('로컬 정리가 실패해도 저장·ack 가 끝났으면 saved', () async {
    when(() => gallery.saveImage(any())).thenAnswer((_) async {});
    final failing = ReceiveService(
      repository: repository,
      transfer: transfer,
      gallery: gallery,
      tempDir: () async => dir,
      onReceived: (_) async => throw StateError('disposed'),
    );

    expect(await failing.receive(photoWithUrl('p1')), ReceiveOutcome.saved);
    verify(() => repository.ackReceived('p1')).called(1);
  });
}
