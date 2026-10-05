import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_error.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/me_repository.dart';
import '../data/models/me.dart';

part 'me_controller.g.dart';

/// `GET /me` 상태. 로그인하지 않았으면 null.
@Riverpod(keepAlive: true)
class MeController extends _$MeController {
  @override
  Future<Me?> build() async {
    final auth = ref.watch(authControllerProvider);
    if (auth != AuthStatus.signedIn) return null;
    try {
      return await ref.watch(meRepositoryProvider).getMe();
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.unauthorized ||
          e.code == ApiErrorCode.authInvalidRefreshToken) {
        scheduleMicrotask(
          () => ref.read(authControllerProvider.notifier).sessionExpired(),
        );
      }
      rethrow;
    }
  }

  /// 서버에서 다시 읽는다. 이전 값은 로딩 중에도 유지된다.
  Future<Me?> reload() {
    ref.invalidateSelf();
    return future;
  }

  /// 촬영 직후처럼 응답으로 받은 잔량을 즉시 반영한다.
  void setFilmBalance(int balance) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(filmBalance: balance));
  }
}
