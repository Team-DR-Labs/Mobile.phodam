import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phodam/app/routes.dart';
import 'package:phodam/features/auth/presentation/auth_controller.dart';

import '../helpers/fixtures.dart' as f;
import 'package:phodam/app/push_routes.dart';

void main() {
  test('푸시 종류별로 열 화면을 정한다', () {
    expect(routeForPush({'type': 'date_revealed', 'date_id': 'd1'}),
        AppRoutes.diaryDetail('d1'));
    expect(routeForPush({'type': 'date_started', 'date_id': 'd1'}),
        AppRoutes.topic('d1'));
    expect(routeForPush({'type': 'partner_submitted', 'date_id': 'd1'}),
        AppRoutes.topic('d1'));
    expect(routeForPush({'type': 'deadline_soon', 'date_id': 'd1'}),
        AppRoutes.topic('d1'));
    expect(routeForPush({'type': 'unknown', 'date_id': 'd1'}), AppRoutes.home);
    expect(routeForPush({'type': 'date_started'}), isNull);
  });

  test('준비 전에 연 알림은 보류했다가 준비되면 한 번만 적용한다', () {
    final link = PendingDeepLink();

    expect(link.offer('/diary/d1', ready: false), isNull);
    expect(link.release(ready: false), isNull);
    expect(link.release(ready: true), '/diary/d1');
    expect(link.release(ready: true), isNull);
    expect(link.offer('/diary/d2', ready: true), '/diary/d2');
  });

  test('로그인·/me·커플 연결이 모두 끝나야 준비 상태', () {
    expect(isReadyForDeepLink(AuthStatus.unknown, const AsyncData(null)), isFalse);
    expect(isReadyForDeepLink(AuthStatus.signedIn, const AsyncLoading()), isFalse);
    expect(isReadyForDeepLink(
        AuthStatus.signedIn, AsyncData(f.me(withCouple: false))), isFalse);
    expect(isReadyForDeepLink(AuthStatus.signedIn, AsyncData(f.me())), isTrue);
  });
}
