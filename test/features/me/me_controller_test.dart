import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phodam/core/network/api_error.dart';
import 'package:phodam/core/storage/secure_storage.dart';
import 'package:phodam/features/auth/presentation/auth_controller.dart';
import 'package:phodam/features/me/data/me_repository.dart';
import 'package:phodam/features/me/presentation/me_controller.dart';

import '../../helpers/fake_secure_storage.dart';

class MockMeRepository extends Mock implements MeRepository {}

void main() {
  test('/me 가 401 이어도 MeController 는 로그아웃하지 않는다(판단은 인터셉터)', () async {
    final repository = MockMeRepository();
    when(repository.getMe)
        .thenThrow(const ApiException(ApiErrorCode.unauthorized));
    final storage = FakeSecureStorage(accessToken: 'a', refreshToken: 'r');
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        meRepositoryProvider.overrideWithValue(repository),
        secureStorageProvider.overrideWithValue(storage),
      ],
    );
    container.listen(meControllerProvider, (_, _) {});
    await pumpEventQueue();

    expect(container.read(meControllerProvider).hasError, isTrue);
    await pumpEventQueue();
    expect(container.read(authControllerProvider), AuthStatus.signedIn);
    expect(storage.refreshToken, 'r');
  });
}
