import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/auth/session_events.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_models.dart';
import '../data/social_sign_in.dart';

part 'auth_controller.g.dart';

enum AuthStatus { unknown, signedIn, signedOut }

/// 로그인 여부. 토큰은 secure storage 에 둔다.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  AuthStatus build() {
    final sub = ref
        .watch(sessionEventsProvider)
        .onExpired
        .listen((_) => sessionExpired());
    ref.onDispose(sub.cancel);
    unawaited(_restore());
    return AuthStatus.unknown;
  }

  SecureStorage get _storage => ref.read(secureStorageProvider);

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    final token = await _storage.readRefreshToken();
    if (!ref.mounted || state != AuthStatus.unknown) return;
    state = (token == null || token.isEmpty)
        ? AuthStatus.signedOut
        : AuthStatus.signedIn;
  }

  Future<void> signInWithDev(String devId, {String? nickname}) async {
    await _persist(
      await _repository.loginDev(devId: devId.trim(), nickname: nickname),
    );
  }

  /// 취소하면 false.
  Future<bool> signInWithApple() async {
    final credential = await ref.read(socialSignInProvider).signInWithApple();
    if (credential == null) return false;
    await _persist(
      await _repository.loginApple(
        identityToken: credential.identityToken,
        nickname: credential.nickname,
      ),
    );
    return true;
  }

  /// 취소하면 false.
  Future<bool> signInWithGoogle() async {
    final idToken = await ref.read(socialSignInProvider).signInWithGoogle();
    if (idToken == null) return false;
    await _persist(await _repository.loginGoogle(idToken: idToken));
    return true;
  }

  Future<void> _persist(AuthResponse response) async {
    await _storage.writeTokens(
      AuthTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      ),
    );
    await _storage.writeUserId(response.user.id);
    if (ref.mounted) state = AuthStatus.signedIn;
  }

  Future<void> signOut() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _repository.logout(refreshToken: refreshToken);
      } catch (e) {
        ref.read(appLoggerProvider).w('logout 실패(무시)', error: e);
      }
    }
    await _storage.clearTokens();
    if (ref.mounted) state = AuthStatus.signedOut;
  }

  /// 리프레시 실패 등으로 세션이 끝났을 때.
  Future<void> sessionExpired() async {
    if (state == AuthStatus.signedOut) return;
    await _storage.clearTokens();
    if (ref.mounted) state = AuthStatus.signedOut;
  }
}
