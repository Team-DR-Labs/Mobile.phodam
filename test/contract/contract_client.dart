import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:phodam/core/auth/session_events.dart';
import 'package:phodam/core/logger/app_logger.dart';
import 'package:phodam/core/network/dio_factory.dart';
import 'package:phodam/core/network/dio_provider.dart';
import 'package:phodam/core/storage/secure_storage.dart';
import 'package:phodam/features/auth/presentation/auth_controller.dart';
import 'package:phodam/features/camera/data/photo_repository.dart';
import 'package:phodam/features/camera/data/upload_queue_store.dart';
import 'package:phodam/features/couple/data/couple_repository.dart';
import 'package:phodam/features/date/data/date_repository.dart';
import 'package:phodam/features/diary/data/diary_repository.dart';
import 'package:phodam/features/me/data/me_repository.dart';

import '../helpers/fake_secure_storage.dart';

/// 계약 테스트 대상 서버. `--dart-define=CONTRACT_BASE_URL=...` 로 바꿀 수 있다.
const contractBaseUrl = String.fromEnvironment(
  'CONTRACT_BASE_URL',
  defaultValue: 'http://localhost:8080/v1',
);

/// 한 사용자의 앱 인스턴스. 앱의 provider 그래프를 그대로 쓰고
/// 토큰 저장소와 업로드 큐 디렉터리만 테스트용으로 바꾼다.
class ContractClient {
  ContractClient(this.name)
      : storage = FakeSecureStorage(),
        queueDir = Directory.systemTemp.createTempSync('contract_$name') {
    final logger = Logger(level: Level.warning);
    late final ProviderContainer created;
    dio = createApiDio(
      baseUrl: contractBaseUrl,
      storage: storage,
      logger: logger,
      onSessionExpired: () {
        sessionExpiredCount++;
        created.read(sessionEventsProvider).expire();
      },
    );
    created = ProviderContainer(
      overrides: [
        appLoggerProvider.overrideWithValue(logger),
        secureStorageProvider.overrideWithValue(storage),
        dioProvider.overrideWithValue(dio),
        transferDioProvider.overrideWithValue(createTransferDio(logger)),
        uploadQueueStoreProvider
            .overrideWithValue(UploadQueueStore(() async => queueDir)),
      ],
      retry: (_, _) => null,
    );
    container = created;
    container.listen(authControllerProvider, (_, _) {});
  }

  final String name;
  final FakeSecureStorage storage;
  final Directory queueDir;
  late final Dio dio;
  late final ProviderContainer container;
  int sessionExpiredCount = 0;

  MeRepository get me => container.read(meRepositoryProvider);
  CoupleRepository get couple => container.read(coupleRepositoryProvider);
  DateRepository get dates => container.read(dateRepositoryProvider);
  PhotoRepository get photos => container.read(photoRepositoryProvider);
  DiaryRepository get diaries => container.read(diaryRepositoryProvider);
  AuthController get auth => container.read(authControllerProvider.notifier);

  void dispose() {
    container.dispose();
    dio.close();
    if (queueDir.existsSync()) queueDir.deleteSync(recursive: true);
  }
}
