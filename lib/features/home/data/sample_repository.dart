import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_provider.dart';
import 'models/sample_item.dart';
import 'sample_api.dart';

part 'sample_repository.g.dart';

class SampleRepository {
  SampleRepository(this._api);

  final SampleApi _api;

  Future<List<SampleItem>> fetchItems({int limit = 20}) =>
      _api.getItems(limit);
}

@riverpod
SampleRepository sampleRepository(Ref ref) {
  return SampleRepository(SampleApi(ref.watch(dioProvider)));
}
