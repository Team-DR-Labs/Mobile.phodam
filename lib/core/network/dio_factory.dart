import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';
import 'logging_interceptor.dart';
import 'token_refresher.dart';

BaseOptions _apiOptions(String baseUrl) => BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
    );

/// 서버 API 용 Dio. 토큰 첨부와 401 갱신·재시도를 담당한다.
///
/// 앱 provider 와 계약 테스트가 같은 구성을 쓰도록 분리했다.
Dio createApiDio({
  required String baseUrl,
  required SecureStorage storage,
  required Logger logger,
  required void Function() onSessionExpired,
}) {
  // 갱신·재시도용. 인증 인터셉터가 없어야 재귀 갱신이 일어나지 않는다.
  final plain = Dio(_apiOptions(baseUrl))
    ..interceptors.add(LoggingInterceptor(logger));
  final refresher = TokenRefresherService(plainDio: plain, storage: storage);
  return Dio(_apiOptions(baseUrl))
    ..interceptors.addAll([
      AuthInterceptor(
        storage: storage,
        retryDio: plain,
        refresh: refresher.refresh,
        onSessionExpired: onSessionExpired,
      ),
      LoggingInterceptor(logger),
    ]);
}

/// presigned URL 업로드·다운로드용 Dio. 인증 헤더를 붙이지 않는다.
Dio createTransferDio(Logger logger) => Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    )..interceptors.add(LoggingInterceptor(logger));
