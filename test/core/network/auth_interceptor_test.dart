import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phodam/core/network/api_error.dart';
import 'package:phodam/core/network/auth_interceptor.dart';
import 'package:phodam/core/storage/secure_storage.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/fake_secure_storage.dart';

void main() {
  late FakeSecureStorage storage;
  late FakeAdapter adapter;
  late Dio dio;
  late int refreshCalls;
  late int expiredCalls;
  late Future<String?> Function() refreshImpl;

  /// 'Bearer new' 만 통과시키는 서버.
  Future<ResponseBody> server(RequestOptions o) async {
    if (o.path == '/auth/dev') return jsonBody({'code': 'UNAUTHORIZED'}, 401);
    if (o.headers['Authorization'] == 'Bearer new') {
      return jsonBody({'ok': true}, 200);
    }
    return jsonBody({'code': 'UNAUTHORIZED', 'message': 'expired'}, 401);
  }

  setUp(() {
    storage = FakeSecureStorage(accessToken: 'old', refreshToken: 'r1');
    adapter = FakeAdapter(server);
    refreshCalls = 0;
    expiredCalls = 0;
    refreshImpl = () async {
      await storage.writeTokens(
        const AuthTokens(accessToken: 'new', refreshToken: 'r2'),
      );
      return 'new';
    };
    final retryDio = Dio()..httpClientAdapter = adapter;
    dio = Dio()
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(
          storage: storage,
          retryDio: retryDio,
          refresh: () {
            refreshCalls++;
            return refreshImpl();
          },
          onSessionExpired: () => expiredCalls++,
        ),
      );
  });

  test('401 이면 한 번 갱신하고 새 토큰으로 재시도한다', () async {
    final response = await dio.get<dynamic>('/me');

    expect(response.statusCode, 200);
    expect(refreshCalls, 1);
    expect(adapter.requests.last.headers['Authorization'], 'Bearer new');
    expect(storage.refreshToken, 'r2');
  });

  test('동시에 401 을 받아도 갱신은 한 번만 한다', () async {
    final gate = Completer<void>();
    refreshImpl = () async {
      await gate.future;
      await storage.writeTokens(
        const AuthTokens(accessToken: 'new', refreshToken: 'r2'),
      );
      return 'new';
    };

    final requests = Future.wait([
      dio.get<dynamic>('/me'),
      dio.get<dynamic>('/dates/1'),
      dio.get<dynamic>('/diaries'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete();
    final responses = await requests;

    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(refreshCalls, 1);
  });

  test('이미 다른 요청이 갱신했으면 저장된 토큰으로 바로 재시도한다', () async {
    // 이전 토큰으로 보낸 요청이 401 을 받는 사이 다른 요청이 갱신을 끝낸 상황.
    adapter = FakeAdapter((o) async {
      if (o.headers['Authorization'] == 'Bearer old') {
        storage.accessToken = 'new';
      }
      return server(o);
    });
    dio.httpClientAdapter = adapter;
    final interceptor = dio.interceptors.whereType<AuthInterceptor>().single;
    dio.interceptors
      ..remove(interceptor)
      ..add(
        AuthInterceptor(
          storage: storage,
          retryDio: Dio()..httpClientAdapter = adapter,
          refresh: () async {
            refreshCalls++;
            return 'never';
          },
          onSessionExpired: () => expiredCalls++,
        ),
      );

    final response = await dio.get<dynamic>('/me');

    expect(response.statusCode, 200);
    expect(refreshCalls, 0);
  });

  test('갱신이 무효면 세션 만료를 알리고 원래 오류를 전달한다', () async {
    refreshImpl = () async => null;

    await expectLater(
      dio.get<dynamic>('/me'),
      throwsA(isA<DioException>()
          .having((e) => e.response?.statusCode, 'status', 401)),
    );
    expect(expiredCalls, 1);
  });

  test('갱신 중 네트워크 오류면 로그아웃하지 않는다', () async {
    refreshImpl = () async => throw DioException.connectionError(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          reason: 'offline',
        );

    final error = await dio
        .get<dynamic>('/me')
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(expiredCalls, 0);
    expect(ApiException.from(error!).code, ApiErrorCode.network,
        reason: '원래 401 대신 갱신 오류를 전달해 위에서 로그아웃으로 오인하지 않는다');
  });

  test('갱신 요청이 5xx 면 로그아웃하지 않고 서버 오류로 전달한다', () async {
    refreshImpl = () async => throw DioException(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/refresh'),
            statusCode: 503,
            data: {'code': 'INTERNAL_ERROR', 'message': 'down'},
          ),
          type: DioExceptionType.badResponse,
        );

    final error = await dio
        .get<dynamic>('/me')
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(expiredCalls, 0);
    expect(ApiException.from(error!).code, ApiErrorCode.internalError);
  });

  test('로그인 경로의 401 은 갱신하지 않는다', () async {
    await expectLater(
      dio.post<dynamic>('/auth/dev', data: {'dev_id': 'a'}),
      throwsA(isA<DioException>()),
    );
    expect(refreshCalls, 0);
    expect(adapter.requests.single.headers['Authorization'], isNull);
  });
}
