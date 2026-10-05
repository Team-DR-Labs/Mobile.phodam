import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/time/formatters.dart';

import '../../../core/widgets/dami.dart';
import '../../../core/widgets/error_view.dart';
import '../../../mock/mock_backend.dart';
import '../../../mock/mock_debug_panel.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../me/presentation/me_controller.dart';
import '../data/models/couple_models.dart';
import 'couple_controller.dart';

class CouplePage extends ConsumerStatefulWidget {
  const CouplePage({super.key});

  @override
  ConsumerState<CouplePage> createState() => _CouplePageState();
}

class _CouplePageState extends ConsumerState<CouplePage> {
  final _code = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!isValidInviteCode(_code.text)) {
      showMessage(context, '8자리 초대 코드를 확인해 주세요.');
      return;
    }
    setState(() => _joining = true);
    try {
      await ref.read(inviteControllerProvider.notifier).join(_code.text);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('커플 연결'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(meControllerProvider.notifier).reload(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const DamiSays('함께 담을 사람과 연결해 주세요.\n한 명이 코드를 만들고, 다른 한 명이 입력하면 돼요.'),
            const SizedBox(height: 24),
            Text('내 초대 코드', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const _InviteCard(),
            const SizedBox(height: 32),
            Text('상대 코드 입력', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              decoration: const InputDecoration(hintText: '예: K7QM2XPA'),
              style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 4),
            ),
            FilledButton(
              onPressed: _joining ? null : _join,
              child: const Text('연결하기'),
            ),
            const SizedBox(height: 24),
            MockDebugPanel(
              actions: [
                MockAction('가상의 상대와 바로 연결', (b) {
                  b.debugConnectPartner();
                  return null;
                }),
                MockAction('상대가 내 코드 입력', (b) {
                  b.debugPartnerAcceptMyInvite();
                  return null;
                }),
                MockAction('상대 초대 코드 받기', (b) {
                  final code = b.debugPartnerInviteCode();
                  _code.text = code;
                  return '상대 코드: $code';
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invite = ref.watch(inviteControllerProvider);
    final controller = ref.read(inviteControllerProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: invite.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(error: e, onRetry: controller.create),
          data: (value) => value == null
              ? OutlinedButton(
                  onPressed: controller.create,
                  child: const Text('초대 코드 만들기'),
                )
              : _InviteCode(
                  invite: value,
                  onRenew: controller.create,
                  onCheck: () =>
                      ref.read(meControllerProvider.notifier).reload(),
                ),
        ),
      ),
    );
  }
}

class _InviteCode extends StatelessWidget {
  const _InviteCode({
    required this.invite,
    required this.onRenew,
    required this.onCheck,
  });

  final Invite invite;
  final VoidCallback onRenew;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expires = Formats.dateTime(invite.expiresAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          invite.code,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium
              ?.copyWith(letterSpacing: 6, fontWeight: FontWeight.w700),
        ),
        Text('$expires까지 유효', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: invite.code));
                  if (context.mounted) showMessage(context, '코드를 복사했어요.');
                },
                icon: const Icon(Icons.copy),
                label: const Text('복사'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: onRenew,
                child: const Text('새 코드'),
              ),
            ),
          ],
        ),
        TextButton(onPressed: onCheck, child: const Text('상대가 입력했나요? 연결 확인')),
      ],
    );
  }
}
