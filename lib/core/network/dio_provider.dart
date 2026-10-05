import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_events.dart';
import '../config/env.dart';
import '../logger/app_logger.dart';
import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';
import 'logging_interceptor.dart';
import 'token_refresher.dart';

part 'dio_provider.g.dart';

BaseOptions _apiOptions() => BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    );

/// 서버 API 용 Dio. 토큰 첨부와 401 갱신·재시도를 담당한다.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final logger = ref.watch(appLoggerProvider);
  final storage = ref.watch(secureStorageProvider);
  final plain = Dio(_apiOptions())
    ..interceptors.add(LoggingInterceptor(logger));
  final refresher = TokenRefresherService(plainDio: plain, storage: storage);

  final dio = Dio(_apiOptions());
  dio.interceptors.addAll([
    AuthInterceptor(
      storage: storage,
      retryDio: plain,
      refresh: refresher.refresh,
      onSessionExpired: () => ref.read(sessionEventsProvider).expire(),
    ),
    LoggingInterceptor(logger),
  ]);
  ref.onDispose(() {
    dio.close();
    plain.close();
  });
  return dio;
}

/// presigned URL 업로드·다운로드용 Dio. 인증 헤더를 붙이지 않는다.
@Riverpod(keepAlive: true)
Dio transferDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  )..interceptors.add(LoggingInterceptor(ref.watch(appLoggerProvider)));
  ref.onDispose(dio.close);
  return dio;
}
