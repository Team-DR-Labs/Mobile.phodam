import 'package:flutter/foundation.dart';

/// `--dart-define-from-file=env/<env>.json` 으로 주입되는 컴파일 타임 설정.
abstract final class Env {
  /// define 없이 만든 빌드는 운영으로 본다(개발 도구가 새지 않도록).
  static const name = String.fromEnvironment('ENV', defaultValue: 'prod');
  static const baseUrl = String.fromEnvironment('BASE_URL');

  /// true 면 서버 대신 인메모리 가짜 서버(MockBackend)를 쓴다.
  static const useMock = bool.fromEnvironment('USE_MOCK');

  /// Google 로그인 서버 클라이언트 ID (ID 토큰 aud). 비어 있으면 Google 로그인 비활성.
  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// iOS 용 Google 클라이언트 ID. Info.plist 의 GIDClientID 로 대신할 수 있다.
  static const googleIosClientId =
      String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool get isProd => name == 'prod';

  /// 개발용 로그인·가짜(다미) 카메라 노출 여부.
  static bool get devToolsEnabled =>
      devToolsAllowed(name: name, releaseMode: kReleaseMode);

  /// dev·mock 을 명시했고 릴리스 빌드가 아닐 때만 허용한다.
  static bool devToolsAllowed({
    required String name,
    required bool releaseMode,
  }) =>
      !releaseMode && (name == 'dev' || name == 'mock');

  static bool get googleSignInConfigured => googleServerClientId.isNotEmpty;
}
