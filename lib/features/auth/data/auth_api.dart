import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'models/auth_models.dart';

part 'auth_api.g.dart';

@RestApi()
abstract class AuthApi {
  factory AuthApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) =
      _AuthApi;

  @POST('/auth/apple')
  Future<AuthResponse> loginApple(@Body() Map<String, dynamic> body);

  @POST('/auth/google')
  Future<AuthResponse> loginGoogle(@Body() Map<String, dynamic> body);

  @POST('/auth/dev')
  Future<AuthResponse> loginDev(@Body() Map<String, dynamic> body);

  @POST('/auth/logout')
  Future<void> logout(@Body() Map<String, dynamic> body);
}
