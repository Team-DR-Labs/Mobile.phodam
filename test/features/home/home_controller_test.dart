import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phodam/features/home/data/models/sample_item.dart';
import 'package:phodam/features/home/data/sample_repository.dart';
import 'package:phodam/features/home/presentation/home_controller.dart';

class MockSampleRepository extends Mock implements SampleRepository {}

void main() {
  late MockSampleRepository repository;

  setUp(() {
    repository = MockSampleRepository();
  });

  // Riverpod 3 는 실패한 provider 를 자동 재시도하므로 테스트에서는 끈다.
  ProviderContainer createContainer() => ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [sampleRepositoryProvider.overrideWithValue(repository)],
      );

  test('build 시 저장소의 아이템을 불러온다', () async {
    const items = [SampleItem(id: 1, title: 'hello')];
    when(() => repository.fetchItems()).thenAnswer((_) async => items);

    final container = createContainer();

    await expectLater(
      container.read(homeControllerProvider.future),
      completion(items),
    );
  });

  test('저장소 오류 시 AsyncError 상태가 된다', () async {
    when(() => repository.fetchItems())
        .thenAnswer((_) async => throw Exception('network'));

    final container = createContainer();
    final sub = container.listen(homeControllerProvider, (_, _) {});

    await expectLater(
      container.read(homeControllerProvider.future),
      throwsException,
    );
    expect(sub.read(), isA<AsyncError<List<SampleItem>>>());
  });
}
