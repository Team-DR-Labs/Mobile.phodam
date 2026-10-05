import 'package:phodam/core/storage/secure_storage.dart';

class FakeSecureStorage implements SecureStorage {
  FakeSecureStorage({this.accessToken, this.refreshToken});

  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeTokens(AuthTokens tokens) async {
    accessToken = tokens.accessToken;
    refreshToken = tokens.refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }

  @override
  Future<void> clear() => clearTokens();
}
