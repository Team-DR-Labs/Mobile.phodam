import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_events.dart';
import '../config/env.dart';
import '../logger/app_logger.dart';
import '../storage/secure_storage.dart';
import 'dio_factory.dart';

part 'dio_provider.g.dart';

/// 서버 API 용 Dio. 토큰 첨부와 401 갱신·재시도를 담당한다.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = createApiDio(
    baseUrl: Env.baseUrl,
    storage: ref.watch(secureStorageProvider),
    logger: ref.watch(appLoggerProvider),
    onSessionExpired: () => ref.read(sessionEventsProvider).expire(),
  );
  ref.onDispose(dio.close);
  return dio;
}

/// presigned URL 업로드·다운로드용 Dio. 인증 헤더를 붙이지 않는다.
@Riverpod(keepAlive: true)
Dio transferDio(Ref ref) {
  final dio = createTransferDio(ref.watch(appLoggerProvider));
  ref.onDispose(dio.close);
  return dio;
}
