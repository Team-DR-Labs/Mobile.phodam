# phodam

Flutter 앱 (iOS / Android). Flutter 3.47.6 · Dart 3.13.5 기준.

## 스택

| 영역 | 패키지 |
|---|---|
| 상태관리 / DI | flutter_riverpod 3 + riverpod_generator 4 |
| 라우팅 | go_router |
| 네트워크 | dio + retrofit |
| 모델 | freezed + json_serializable |
| 보안 저장소 | flutter_secure_storage |
| 로깅 | logger |
| 테스트 | flutter_test + mocktail |

## 시작하기

```bash
flutter pub get
dart run build_runner build -d      # 생성 파일(*.g.dart, *.freezed.dart)은 커밋하지 않는다
flutter run --dart-define-from-file=env/dev.json
```

개발 중에는 `dart run build_runner watch -d` 로 자동 생성한다.

## 환경

`env/<env>.json` 을 `--dart-define-from-file` 로 주입하고 `lib/core/config/env.dart` 에서 읽는다.
비밀값은 이 파일에 넣지 않는다.

| 파일 | 용도 |
|---|---|
| `env/dev.json` | 개발 |
| `env/prod.json` | 운영 |

VS Code 는 `.vscode/launch.json` 의 `phodam (dev)` / `phodam (prod)` 구성을 쓴다.

## 구조 (feature-first)

```
lib/
  main.dart
  app/                  # App, 라우터
  core/                 # env, network(dio·인터셉터), storage, logger, theme
  features/<feature>/
    data/               # models(freezed), api(retrofit), repository
    presentation/       # controller(AsyncNotifier), page
```

새 기능은 `features/home` 을 복사해 시작한다.

## 검증

```bash
flutter analyze
flutter test
```
