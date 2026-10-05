import 'package:dio/dio.dart';

/// 서버 ErrorResponse.code 와 앱 내부 오류 분류.
///
/// 앱은 message 가 아니라 code 로만 분기한다(mvp-policy §13).
enum ApiErrorCode {
  validationFailed,
  unauthorized,
  authInvalidIdToken,
  authInvalidRefreshToken,
  forbidden,
  coupleRequired,
  notFound,
  coupleAlreadyConnected,
  inviteInvalid,
  dateAlreadyInProgress,
  dateNotActive,
  dateNotJoined,
  alreadySubmitted,
  filmExhausted,
  photoNotUploaded,
  photoInvalid,
  receiveNotAvailable,
  internalError,

  /// 앱 전용: 연결 실패·타임아웃.
  network,

  /// 앱 전용: 해석할 수 없는 응답.
  unknown;

  /// 서버 표기(`FILM_EXHAUSTED`).
  String get wire => name
      .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]}')
      .toUpperCase();

  static ApiErrorCode fromWire(String? code) {
    for (final value in values) {
      if (value.wire == code) return value;
    }
    return unknown;
  }
}

class ApiException implements Exception {
  const ApiException(this.code, {this.message, this.statusCode});

  final ApiErrorCode code;
  final String? message;
  final int? statusCode;

  /// 어떤 오류든 [ApiException] 으로 바꾼다.
  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) return _fromDio(error);
    return ApiException(ApiErrorCode.unknown, message: error.toString());
  }

  static ApiException _fromDio(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    if (data is Map && data['code'] is String) {
      return ApiException(
        ApiErrorCode.fromWire(data['code'] as String),
        message: data['message'] as String?,
        statusCode: status,
      );
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const ApiException(ApiErrorCode.network);
      default:
        break;
    }
    if (status == 401) {
      return ApiException(ApiErrorCode.unauthorized, statusCode: status);
    }
    if (status == 404) {
      return ApiException(ApiErrorCode.notFound, statusCode: status);
    }
    return ApiException(
      ApiErrorCode.unknown,
      message: error.message,
      statusCode: status,
    );
  }

  /// 사용자에게 보여줄 한국어 문구.
  String get userMessage => switch (code) {
        ApiErrorCode.validationFailed => '입력한 내용을 다시 확인해 주세요.',
        ApiErrorCode.unauthorized ||
        ApiErrorCode.authInvalidRefreshToken =>
          '로그인이 만료됐어요. 다시 로그인해 주세요.',
        ApiErrorCode.authInvalidIdToken => '로그인에 실패했어요. 다시 시도해 주세요.',
        ApiErrorCode.forbidden => '접근할 수 없어요.',
        ApiErrorCode.coupleRequired => '먼저 상대와 연결해 주세요.',
        ApiErrorCode.notFound => '찾을 수 없어요.',
        ApiErrorCode.coupleAlreadyConnected => '이미 연결된 계정이에요.',
        ApiErrorCode.inviteInvalid => '초대 코드가 올바르지 않거나 만료됐어요.',
        ApiErrorCode.dateAlreadyInProgress => '이미 진행 중인 데이트가 있어요.',
        ApiErrorCode.dateNotActive => '이미 끝난 데이트예요.',
        ApiErrorCode.dateNotJoined => '먼저 주제를 확인해 주세요.',
        ApiErrorCode.alreadySubmitted => '이미 제출했어요.',
        ApiErrorCode.filmExhausted => '남은 필름이 없어요.',
        ApiErrorCode.photoNotUploaded => '아직 업로드되지 않은 사진이에요.',
        ApiErrorCode.photoInvalid => '사진을 올릴 수 없어요.',
        ApiErrorCode.receiveNotAvailable => '사진을 받을 수 있는 기간이 아니에요.',
        ApiErrorCode.internalError => '잠시 후 다시 시도해 주세요.',
        ApiErrorCode.network => '네트워크 연결을 확인해 주세요.',
        ApiErrorCode.unknown => '문제가 생겼어요. 다시 시도해 주세요.',
      };

  @override
  String toString() => 'ApiException(${code.wire}, $statusCode, $message)';
}

/// 원격 호출 오류를 [ApiException] 으로 통일한다.
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (error) {
    throw ApiException.from(error);
  }
}

/// UI 표시용: 어떤 오류든 사용자 문구로.
String userMessageOf(Object error) => ApiException.from(error).userMessage;
