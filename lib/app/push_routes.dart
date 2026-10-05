import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/me/data/models/me.dart';
import 'routes.dart';

/// 푸시 data(`{type, date_id}`)를 열 화면 경로로 바꾼다(mvp-policy §12).
String? routeForPush(Map<String, dynamic> data) {
  final dateId = data['date_id'];
  if (dateId is! String || dateId.isEmpty) return null;
  return switch (data['type']) {
    'date_revealed' => AppRoutes.diaryDetail(dateId),
    'date_started' ||
    'partner_submitted' ||
    'deadline_soon' =>
      AppRoutes.topic(dateId),
    _ => AppRoutes.home,
  };
}

/// 로그인·`/me`·커플 연결이 끝나 화면 이동이 가능한 상태.
bool isReadyForDeepLink(AuthStatus auth, AsyncValue<Me?> me) =>
    auth == AuthStatus.signedIn && me.value?.couple != null;

/// 앱이 준비되기 전에 탭한 알림의 이동을 보류했다가 준비되면 적용한다.
class PendingDeepLink {
  String? _pending;

  String? get pending => _pending;

  /// 지금 이동할 경로를 돌려준다. 준비 전이면 보류하고 null.
  String? offer(String route, {required bool ready}) {
    if (ready) {
      _pending = null;
      return route;
    }
    _pending = route;
    return null;
  }

  /// 준비되었으면 보류한 경로를 꺼낸다.
  String? release({required bool ready}) {
    if (!ready) return null;
    final route = _pending;
    _pending = null;
    return route;
  }
}
