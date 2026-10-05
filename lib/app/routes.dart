/// 화면 경로.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const couple = '/couple';
  static const home = '/';
  static const diary = '/diary';

  static String topic(String dateId) => '/dates/$dateId/topic';
  static String camera(String dateId) => '/dates/$dateId/camera';
  static String submit(String dateId) => '/dates/$dateId/submit';
  static String develop(String dateId) => '/dates/$dateId/develop';
  static String receive(String dateId) => '/dates/$dateId/receive';
  static String waiting(String dateId) => '/dates/$dateId/waiting';
  static String diaryDetail(String dateId) => '/diary/$dateId';

  /// 로그인·연결 전 단계 화면. 준비가 끝나면 홈으로 보낸다.
  static const entry = {splash, login, couple};
}
