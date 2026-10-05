import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phodam/core/auth/session_events.dart';
import 'package:phodam/core/storage/secure_storage.dart';
import 'package:phodam/features/auth/data/auth_repository.dart';
import 'package:phodam/features/auth/data/models/auth_models.dart';
import 'package:phodam/features/auth/data/social_sign_in.dart';
import 'package:phodam/features/auth/presentation/auth_controller.dart';

import '../../helpers/fake_secure_storage.dart';
import '../../helpers/fixtures.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSocialSignIn extends Mock implements SocialSignIn {}

void main() {
  late MockAuthRepository repository;
  late MockSocialSignIn social;
  late FakeSecureStorage storage;

  final response = AuthResponse(
    accessToken: 'a1',
    accessTokenExpiresAt: t0,
    refreshToken: 'r1',
    refreshTokenExpiresAt: t0,
    isNewUser: true,
    user: alice,
  );

  setUp(() {
    repository = MockAuthRepository();
    social = MockSocialSignIn();
    storage = FakeSecureStorage();
  });

  ProviderContainer createContainer() => ProviderContainer.test(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          socialSignInProvider.overrideWithValue(social),
          secureStorageProvider.overrideWithValue(storage),
        ],
      );

  Future<AuthStatus> settle(ProviderContainer container) async {
    container.listen(authControllerProvider, (_, _) {});
    await pumpEventQueue();
    return container.read(authControllerProvider);
  }

  test('저장된 토큰이 없으면 signedOut', () async {
    expect(await settle(createContainer()), AuthStatus.signedOut);
  });

  test('저장된 리프레시 토큰이 있으면 signedIn', () async {
    storage.refreshToken = 'r0';
    expect(await settle(createContainer()), AuthStatus.signedIn);
  });

  test('개발용 로그인은 토큰을 저장하고 signedIn 이 된다', () async {
    when(() => repository.loginDev(devId: 'alice', nickname: null))
        .thenAnswer((_) async => response);
    final container = createContainer();
    await settle(container);

    await container
        .read(authControllerProvider.notifier)
        .signInWithDev(' alice ');

    expect(container.read(authControllerProvider), AuthStatus.signedIn);
    expect(storage.accessToken, 'a1');
    expect(storage.refreshToken, 'r1');
  });

  test('Apple 로그인을 취소하면 서버를 부르지 않는다', () async {
    when(() => social.signInWithApple()).thenAnswer((_) async => null);
    final container = createContainer();
    await settle(container);

    final result =
        await container.read(authControllerProvider.notifier).signInWithApple();

    expect(result, isFalse);
    verifyNever(() => repository.loginApple(
          identityToken: any(named: 'identityToken'),
          nickname: any(named: 'nickname'),
        ));
  });

  test('Apple 로그인은 identity_token 과 이름을 서버에 보낸다', () async {
    when(() => social.signInWithApple()).thenAnswer(
      (_) async => const AppleCredential(identityToken: 'jwt', nickname: '홍길동'),
    );
    when(() => repository.loginApple(identityToken: 'jwt', nickname: '홍길동'))
        .thenAnswer((_) async => response);
    final container = createContainer();
    await settle(container);

    await container.read(authControllerProvider.notifier).signInWithApple();

    expect(container.read(authControllerProvider), AuthStatus.signedIn);
  });

  test('로그아웃은 서버 실패와 관계없이 토큰을 지운다', () async {
    storage
      ..accessToken = 'a0'
      ..refreshToken = 'r0';
    when(() => repository.logout(refreshToken: 'r0'))
        .thenThrow(Exception('offline'));
    final container = createContainer();
    await settle(container);

    await container.read(authControllerProvider.notifier).signOut();

    expect(container.read(authControllerProvider), AuthStatus.signedOut);
    expect(storage.refreshToken, isNull);
  });

  test('세션 만료 이벤트를 받으면 signedOut', () async {
    storage.refreshToken = 'r0';
    final container = createContainer();
    await settle(container);

    container.read(sessionEventsProvider).expire();
    await pumpEventQueue();

    expect(container.read(authControllerProvider), AuthStatus.signedOut);
    expect(storage.refreshToken, isNull);
  });
}
