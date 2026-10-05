import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../me/presentation/me_controller.dart';
import '../data/couple_repository.dart';
import '../data/models/couple_models.dart';

part 'couple_controller.g.dart';

/// 내가 발급한 초대 코드. 아직 없으면 null.
@riverpod
class InviteController extends _$InviteController {
  @override
  Future<Invite?> build() async => null;

  Future<void> create() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(coupleRepositoryProvider).createInvite(),
    );
  }

  /// 상대 코드로 연결한다. 성공하면 `/me` 를 갱신해 홈으로 넘어간다.
  Future<void> join(String code) async {
    await ref.read(coupleRepositoryProvider).join(normalizeInviteCode(code));
    await ref.read(meControllerProvider.notifier).reload();
  }
}

String normalizeInviteCode(String raw) =>
    raw.replaceAll(RegExp(r'\s'), '').toUpperCase();

bool isValidInviteCode(String raw) =>
    RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$')
        .hasMatch(normalizeInviteCode(raw));
