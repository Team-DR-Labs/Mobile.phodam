import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/me/data/models/me.dart';
import 'routes.dart';

/// 미로그인 → 로그인, 커플 없음 → 커플 연결, 그 외 → 요청한 화면(진입 화면이면 홈).
String? resolveRedirect({
  required AuthStatus auth,
  required AsyncValue<Me?> me,
  required String location,
}) {
  String? goTo(String target) => location == target ? null : target;

  switch (auth) {
    case AuthStatus.unknown:
      return goTo(AppRoutes.splash);
    case AuthStatus.signedOut:
      return goTo(AppRoutes.login);
    case AuthStatus.signedIn:
      break;
  }
  final value = me.value;
  if (value == null) return goTo(AppRoutes.splash);
  if (value.couple == null) return goTo(AppRoutes.couple);
  if (AppRoutes.entry.contains(location)) return AppRoutes.home;
  return null;
}
