/// `--dart-define-from-file=env/<env>.json` 으로 주입되는 컴파일 타임 설정.
abstract final class Env {
  static const name = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const baseUrl = String.fromEnvironment('BASE_URL');

  static bool get isProd => name == 'prod';
}
