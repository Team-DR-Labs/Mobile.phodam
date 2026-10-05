import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:phodam/features/couple/data/couple_repository.dart';
import 'package:phodam/features/couple/data/models/couple_models.dart';
import 'package:phodam/features/couple/presentation/couple_controller.dart';
import 'package:phodam/features/me/data/models/me.dart';
import 'package:phodam/features/me/presentation/me_controller.dart';

import '../../helpers/fixtures.dart';

class MockCoupleRepository extends Mock implements CoupleRepository {}

class FakeMeController extends MeController {
  int reloads = 0;

  @override
  Future<Me?> build() async => me();

  @override
  Future<Me?> reload() async {
    reloads++;
    return me();
  }
}

void main() {
  test('초대 코드 형식 검사: 8자, 헷갈리는 문자(0,O,1,I,L) 제외', () {
    expect(isValidInviteCode('k7qm 2xpa'), isTrue);
    expect(isValidInviteCode('K7QM2XP'), isFalse);
    expect(isValidInviteCode('K7QM2XP0'), isFalse);
    expect(isValidInviteCode('K7QM2XPI'), isFalse);
  });

  test('코드로 연결하면 정규화한 코드를 보내고 /me 를 갱신한다', () async {
    final repository = MockCoupleRepository();
    final meController = FakeMeController();
    when(() => repository.join('K7QM2XPA')).thenAnswer((_) async => couple());
    final container = ProviderContainer.test(
      overrides: [
        coupleRepositoryProvider.overrideWithValue(repository),
        meControllerProvider.overrideWith(() => meController),
      ],
    );

    await container.read(inviteControllerProvider.notifier).join(' k7qm2xpa ');

    verify(() => repository.join('K7QM2XPA')).called(1);
    expect(meController.reloads, 1);
  });

  test('초대 코드를 발급하면 상태에 담긴다', () async {
    final repository = MockCoupleRepository();
    final invite = Invite(code: 'ABCDEFGH', expiresAt: t0);
    when(repository.createInvite).thenAnswer((_) async => invite);
    final container = ProviderContainer.test(
      overrides: [coupleRepositoryProvider.overrideWithValue(repository)],
    );
    container.listen(inviteControllerProvider, (_, _) {});

    await container.read(inviteControllerProvider.notifier).create();

    expect(container.read(inviteControllerProvider).value, invite);
  });
}
