import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/env.dart';
import '../logger/app_logger.dart';
import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';
import 'logging_interceptor.dart';

part 'dio_provider.g.dart';

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
  dio.interceptors.addAll([
    AuthInterceptor(ref.watch(secureStorageProvider)),
    LoggingInterceptor(ref.watch(appLoggerProvider)),
  ]);
  ref.onDispose(dio.close);
  return dio;
}
