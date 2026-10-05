import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phodam/app/redirect.dart';
import 'package:phodam/app/routes.dart';
import 'package:phodam/features/auth/presentation/auth_controller.dart';
import 'package:phodam/features/me/data/models/me.dart';

import '../helpers/fixtures.dart' as f;

void main() {
  String? go(AuthStatus auth, AsyncValue<Me?> me, String location) =>
      resolveRedirect(auth: auth, me: me, location: location);

  test('토큰 확인 중이면 스플래시', () {
    expect(go(AuthStatus.unknown, const AsyncData(null), AppRoutes.home),
        AppRoutes.splash);
  });

  test('미로그인이면 로그인 화면', () {
    expect(go(AuthStatus.signedOut, const AsyncData(null), AppRoutes.home),
        AppRoutes.login);
    expect(go(AuthStatus.signedOut, const AsyncData(null), AppRoutes.login),
        isNull);
  });

  test('로그인했지만 /me 로딩 중이면 스플래시', () {
    expect(go(AuthStatus.signedIn, const AsyncLoading(), AppRoutes.login),
        AppRoutes.splash);
  });

  test('커플이 없으면 커플 연결', () {
    final me = AsyncData<Me?>(f.me(withCouple: false));
    expect(go(AuthStatus.signedIn, me, AppRoutes.home), AppRoutes.couple);
    expect(go(AuthStatus.signedIn, me, AppRoutes.couple), isNull);
  });

  test('준비가 끝나면 진입 화면에서 홈으로, 그 외 화면은 그대로', () {
    final me = AsyncData<Me?>(f.me());
    expect(go(AuthStatus.signedIn, me, AppRoutes.couple), AppRoutes.home);
    expect(go(AuthStatus.signedIn, me, AppRoutes.splash), AppRoutes.home);
    expect(go(AuthStatus.signedIn, me, AppRoutes.topic('d1')), isNull);
  });
}
