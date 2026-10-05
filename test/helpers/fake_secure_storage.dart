import 'package:phodam/core/storage/secure_storage.dart';

class FakeSecureStorage implements SecureStorage {
  FakeSecureStorage({this.accessToken, this.refreshToken, this.userId});

  String? accessToken;
  String? refreshToken;
  String? userId;

  @override
  Future<String?> readUserId() async => userId;

  @override
  Future<void> writeUserId(String value) async => userId = value;

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
    userId = null;
  }

  @override
  Future<void> clear() => clearTokens();
}
