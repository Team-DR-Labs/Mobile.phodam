import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/config/env.dart';

part 'social_sign_in.g.dart';

class AppleCredential {
  const AppleCredential({required this.identityToken, this.nickname});

  final String identityToken;

  /// 첫 로그인 때만 Apple 이 이름을 준다.
  final String? nickname;
}

/// 사용자가 로그인을 취소하면 null 을 돌려준다.
abstract interface class SocialSignIn {
  bool get appleAvailable;

  bool get googleAvailable;

  Future<AppleCredential?> signInWithApple();

  Future<String?> signInWithGoogle();
}

class NativeSocialSignIn implements SocialSignIn {
  Future<void>? _googleInit;

  /// Android 의 Apple 로그인은 웹 인증 설정(서비스 ID)이 필요해 MVP 에서는 iOS 만 지원한다.
  @override
  bool get appleAvailable => Platform.isIOS;

  @override
  bool get googleAvailable => Env.googleSignInConfigured;

  @override
  Future<AppleCredential?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.fullName],
      );
      final token = credential.identityToken;
      if (token == null) return null;
      final name =
          '${credential.familyName ?? ''}${credential.givenName ?? ''}'.trim();
      return AppleCredential(
        identityToken: token,
        nickname: name.isEmpty ? null : name,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<String?> signInWithGoogle() async {
    await (_googleInit ??= GoogleSignIn.instance.initialize(
      clientId: Env.googleIosClientId.isEmpty ? null : Env.googleIosClientId,
      serverClientId: Env.googleServerClientId,
    ));
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
SocialSignIn socialSignIn(Ref ref) => NativeSocialSignIn();
