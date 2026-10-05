import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/sample_item.dart';
import '../data/sample_repository.dart';

part 'home_controller.g.dart';

@riverpod
class HomeController extends _$HomeController {
  @override
  Future<List<SampleItem>> build() {
    return ref.watch(sampleRepositoryProvider).fetchItems();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(sampleRepositoryProvider).fetchItems(),
    );
  }
}
