# 포담 (phodam)

함께 담는 사진일기. Flutter 앱 (iOS / Android). Flutter 3.47.6 · Dart 3.13.5 기준.

제품·도메인 기준은 다음 문서를 따른다(이 레포에서는 수정하지 않는다).

- `../podam-spec.md` — 제품 정책, 화면 구성, 확정 결정
- `../Server.phodam/docs/mvp-policy.md` — 상태·공개 규칙·에러 코드
- `../Server.phodam/docs/openapi.yaml` — API 계약(Apidog 정본 동기화본)

## 스택

| 영역 | 패키지 |
|---|---|
| 상태관리 / DI | flutter_riverpod 3 + riverpod_generator 4 |
| 라우팅 | go_router |
| 네트워크 | dio + retrofit |
| 모델 | freezed + json_serializable (snake_case, `build.yaml`) |
| 보안 저장소 | flutter_secure_storage (액세스·리프레시 토큰) |
| 로그인 | sign_in_with_apple, google_sign_in 7 |
| 카메라·이미지 | camera, image (isolate 에서 색감·그레인·리사이즈) |
| 사진첩 저장 | gal ('포담' 앨범) |
| 연결 상태 | connectivity_plus |
| 푸시 | firebase_core, firebase_messaging |
| 로깅 | logger |
| 테스트 | flutter_test + mocktail |

## 시작하기

```bash
flutter pub get
dart run build_runner build -d      # 생성 파일(*.g.dart, *.freezed.dart)은 커밋하지 않는다
```

개발 중에는 `dart run build_runner watch -d` 로 자동 생성한다.

### mock 으로 실행 (서버 없이)

```bash
flutter run --dart-define-from-file=env/mock.json
```

- `lib/mock/mock_backend.dart` 의 인메모리 가짜 서버가 mvp-policy 를 흉내 낸다(필름 차감, 72시간 만료, 상대 주제 비공개, 수령 기한 등). 앱을 껐다 켜면 상태가 사라진다.
- 로그인 화면의 **개발용 로그인**에 아무 dev_id 를 넣는다.
- 2인 시뮬레이션
  - 화면 아래 **개발용: 상대 행동 시뮬레이트** 패널(커플 연결·홈·상대 대기 화면)에서 상대 연결, 상대 데이트 시작·주제 확인·제출, 마감 지나게, 필름 지급을 누른다.
  - 또는 로그아웃 후 다른 dev_id 로 로그인하면 같은 가짜 서버 상태를 공유하므로 두 사람을 번갈아 조작할 수 있다.
- 카메라가 없는 iOS 시뮬레이터에서는 mock·dev 디버그 빌드에 한해 다미 이미지로 촬영한다.

### 실제 서버와 실행 (dev)

```bash
# Server.phodam 을 APP_ENV=local 로 띄운 뒤
flutter run --dart-define-from-file=env/dev.json          # iOS 시뮬레이터
flutter run --dart-define-from-file=env/dev.android.json  # Android 에뮬레이터(10.0.2.2)
```

- iOS 시뮬레이터는 `http://localhost:8080/v1` 로 맥의 서버에 닿는다.
- Android 에뮬레이터는 `10.0.2.2` 가 맥의 localhost 다. 디버그 빌드에만 평문 HTTP 를 허용한다(`android/app/src/debug/AndroidManifest.xml`).
- **실기기**는 같은 Wi-Fi 의 맥 LAN IP 를 써야 한다. `env/dev.json` 을 복사해 `BASE_URL` 을 `http://<맥 LAN IP>:8080/v1` 로 바꾸고,
  **서버의 `STORAGE_PUBLIC_ENDPOINT` 도 같은 호스트(`http://<맥 LAN IP>:9000` 등)로 맞춰야** presigned URL 업로드·다운로드가 동작한다.
  (presigned URL 의 호스트는 서명에 포함되므로 앱에서 바꿔 쓸 수 없다.)
- dev 로그인(`/auth/dev`)은 서버가 `APP_ENV=local` 일 때만 열린다.

VS Code 는 `.vscode/launch.json` 의 `phodam (mock)` / `phodam (dev)` / `phodam (dev, Android emulator)` / `phodam (prod)` 구성을 쓴다.

## 환경 값

`env/<env>.json` 을 `--dart-define-from-file` 로 주입하고 `lib/core/config/env.dart` 에서 읽는다. 비밀값은 넣지 않는다.

| 키 | 설명 |
|---|---|
| `ENV` | `dev` / `mock` / `prod`. 지정하지 않으면 `prod`. 개발용 로그인·가짜(다미) 카메라는 `dev`·`mock` 이면서 릴리스 빌드가 아닐 때만 보인다 |
| `BASE_URL` | `/v1` 까지 포함한 API 주소 |
| `USE_MOCK` | `true` 면 서버 대신 가짜 서버(MockBackend) |
| `GOOGLE_SERVER_CLIENT_ID` | Google 웹(서버) 클라이언트 ID. 서버의 Google `aud` 와 같아야 한다. 비어 있으면 Google 버튼을 숨긴다 |
| `GOOGLE_IOS_CLIENT_ID` | iOS 클라이언트 ID(선택, Info.plist `GIDClientID` 로 대신 가능) |

## 외부 계정이 준비되면 채울 것

- **Apple 로그인**: Apple Developer 에서 App ID(`com.drlabs.podam`)에 Sign in with Apple 활성화. `ios/Runner/Runner.entitlements` 는 이미 연결되어 있다. 서버의 Apple `aud` 는 번들 ID. Android 의 Apple 로그인은 서비스 ID·웹 리다이렉트가 필요해 MVP 에서는 iOS 만 노출한다.
- **Google 로그인**: Google Cloud 콘솔에서 웹(서버)·iOS·Android(패키지 + SHA-1) OAuth 클라이언트 생성 → `GOOGLE_SERVER_CLIENT_ID`(필수), `GOOGLE_IOS_CLIENT_ID` 채우기. iOS 는 `Info.plist` 에 `CFBundleURLTypes` 로 iOS 클라이언트의 reversed client ID URL scheme 을 추가해야 한다.
- **FCM 푸시**
  1. Firebase 프로젝트에 iOS(`com.drlabs.podam`)·Android(`com.drlabs.podam`) 앱 등록
  2. `ios/Runner/GoogleService-Info.plist` 추가(Xcode 에서 Runner 타깃에 포함), APNs 인증 키를 Firebase 에 업로드, Push Notifications capability 확인(`aps-environment` 는 entitlements 에 있음)
  3. `android/app/google-services.json` 추가 후 `android/settings.gradle.kts` 에 `id("com.google.gms.google-services") version "<최신>" apply false`, `android/app/build.gradle.kts` 에 `id("com.google.gms.google-services")` 를 추가
  - 설정 파일이 없으면 앱은 Firebase 초기화 실패를 로그로만 남기고 푸시 없이 동작한다. (그래서 google-services 플러그인은 아직 추가하지 않았다. 파일 없이 추가하면 빌드가 깨진다.)
  - 동작: 권한 요청 → 토큰을 `PUT /me/devices` 로 등록(로그인 시·토큰 갱신 시), 포그라운드 수신 시 `/me` 갱신, 알림 탭 시 `data.date_id` 로 이동(`lib/app/push_routes.dart`).
- **prod**: `env/prod.json` 의 `BASE_URL` 등.

## 구조 (feature-first)

```
lib/
  main.dart
  app/                  # App, 라우터·redirect, 앱 복귀/온라인 동기화, 푸시 라우팅
  core/                 # env, network(dio·토큰 갱신·에러 code), storage, push, theme, widgets
  mock/                 # 인메모리 가짜 서버와 "상대 행동 시뮬레이트" 패널
  features/<feature>/
    data/               # models(freezed), api(retrofit), Repository 인터페이스 + Api*/Mock* 구현
    presentation/       # controller(Notifier/AsyncNotifier), page
```

| feature | 내용 |
|---|---|
| `auth` | Apple/Google/개발용 로그인, 토큰, 스플래시 |
| `me` | `GET /me` — 앱 상태의 중심(라우터 redirect 기준) |
| `couple` | 초대 코드 발급·복사·입력 |
| `home` | 다미, 데이트 시작/참여, 진행 상태, 잔여 매수 |
| `date` | 주제 확인, 상대 대기 |
| `camera` | 필름 카메라, 샷 예약, 색감 처리, 업로드 큐 |
| `submit` | 대표 사진 선택, 글 작성, 제출 |
| `develop` | 현상 연출, 사진 받기(사진첩 저장 → 성공한 장만 ack) |
| `diary` | 날짜별 목록, 상세 |

라우팅: 미로그인 → `/login`, 커플 없음 → `/couple`, 그 외 → 요청 화면(`lib/app/redirect.dart`).

### 정책 메모

- 앱은 에러 `code` 로만 분기한다(`lib/core/network/api_error.dart`).
- 401 이면 리프레시 토큰으로 한 번 갱신하고 재시도한다. 동시 요청은 갱신 하나를 기다리고, 갱신이 무효면 로그아웃한다.
- presigned 업로드·다운로드는 인증 헤더 없는 별도 Dio 로, 서버가 준 `headers` 를 그대로 붙인다.
- 업로드 큐는 앱 문서 디렉터리(`upload_queue/`)에 사진과 목록을 둔다. 실패하면 남겨 두고 앱 복귀·재시작·온라인 복귀·로그인 때 재시도한다. 업로드 URL 이 만료됐으면 재발급받는다. 로컬 사진은 수령 성공 후 지우고, 11일이 지나면 정리한다.
- 제출 전 사진에는 저장·공유 UI 가 없다. 상대 주제는 공동 공개 전 화면에 표시하지 않는다.

## 검증

```bash
dart run build_runner build -d && flutter analyze && flutter test
flutter build ios --simulator --debug --dart-define-from-file=env/mock.json
flutter build apk --debug --dart-define-from-file=env/mock.json
```

실서버 계약 연동 테스트(`test/contract/`, 기본 실행에서는 건너뜀): 로컬 서버(`http://localhost:8080/v1`, `APP_ENV=local`, MinIO `localhost:9000`)를 띄운 뒤
`flutter test --tags contract --run-skipped` (다른 주소는 `--dart-define=CONTRACT_BASE_URL=...`).
