import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'models/sample_item.dart';

part 'sample_api.g.dart';

@RestApi()
abstract class SampleApi {
  factory SampleApi(Dio dio, {String? baseUrl, ParseErrorLogger? errorLogger}) =
      _SampleApi;

  @GET('/posts')
  Future<List<SampleItem>> getItems(@Query('_limit') int limit);
}
