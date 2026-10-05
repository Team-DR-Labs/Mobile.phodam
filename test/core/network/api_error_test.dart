import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phodam/core/network/api_error.dart';

void main() {
  RequestOptions options() => RequestOptions(path: '/x');

  test('서버 code 를 enum 으로 매핑한다', () {
    final error = DioException(
      requestOptions: options(),
      response: Response(
        requestOptions: options(),
        statusCode: 409,
        data: {'code': 'FILM_EXHAUSTED', 'message': 'no film'},
      ),
    );

    final mapped = ApiException.from(error);

    expect(mapped.code, ApiErrorCode.filmExhausted);
    expect(mapped.statusCode, 409);
    expect(mapped.userMessage, '남은 필름이 없어요.');
  });

  test('모든 서버 code 가 왕복 변환된다', () {
    const wire = [
      'VALIDATION_FAILED', 'UNAUTHORIZED', 'AUTH_INVALID_ID_TOKEN',
      'AUTH_INVALID_REFRESH_TOKEN', 'FORBIDDEN', 'COUPLE_REQUIRED',
      'NOT_FOUND', 'COUPLE_ALREADY_CONNECTED', 'INVITE_INVALID',
      'DATE_ALREADY_IN_PROGRESS', 'DATE_NOT_ACTIVE', 'DATE_NOT_JOINED',
      'ALREADY_SUBMITTED', 'FILM_EXHAUSTED', 'PHOTO_NOT_UPLOADED',
      'PHOTO_INVALID', 'RECEIVE_NOT_AVAILABLE', 'INTERNAL_ERROR',
    ];
    for (final code in wire) {
      final value = ApiErrorCode.fromWire(code);
      expect(value, isNot(ApiErrorCode.unknown), reason: code);
      expect(value.wire, code);
    }
  });

  test('연결 오류는 network, 모르는 code 는 unknown', () {
    expect(
      ApiException.from(DioException.connectionError(
        requestOptions: options(),
        reason: 'offline',
      )).code,
      ApiErrorCode.network,
    );
    expect(ApiErrorCode.fromWire('SOMETHING_NEW'), ApiErrorCode.unknown);
  });

  test('guardApi 는 오류를 ApiException 으로 바꾼다', () async {
    await expectLater(
      guardApi<void>(() async => throw StateError('boom')),
      throwsA(isA<ApiException>()),
    );
  });
}
