import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/dami.dart';
import '../../../core/widgets/error_view.dart';
import '../../../mock/mock_backend.dart';
import '../../../mock/mock_debug_panel.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../me/data/models/me.dart';
import '../../me/presentation/me_controller.dart';
import 'home_date_card.dart';
import 'home_stage.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('포담'),
        actions: [
          IconButton(
            tooltip: '일기',
            onPressed: () => context.push(AppRoutes.diary),
            icon: const Icon(Icons.menu_book_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (_) =>
                ref.read(authControllerProvider.notifier).signOut(),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('로그아웃')),
            ],
          ),
        ],
      ),
      body: switch (me) {
        AsyncValue(:final value?) => _HomeBody(me: value),
        AsyncValue(:final error?) => ErrorView(
            error: error,
            onRetry: () => ref.read(meControllerProvider.notifier).reload(),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.me});

  final Me me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = homeStageOf(me);
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => ref.read(meControllerProvider.notifier).reload(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: Dami(size: 150)),
          const SizedBox(height: 16),
          Text(
            damiMessage(stage, me),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Center(
            child: Chip(
              avatar: const Icon(Icons.camera_roll_outlined, size: 18),
              label: Text('남은 필름 ${me.filmBalance}장'),
            ),
          ),
          const SizedBox(height: 16),
          HomeDateCard(me: me, stage: stage),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.diary),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('우리의 일기'),
          ),
          const SizedBox(height: 24),
          MockDebugPanel(
            actions: [
              MockAction('상대가 데이트 시작', (b) {
                b.debugPartnerStartDate();
                return null;
              }),
              MockAction('상대가 주제 확인', (b) {
                b.debugPartnerJoin();
                return null;
              }),
              MockAction('상대가 제출', (b) {
                b.debugPartnerSubmit();
                return null;
              }),
              MockAction('마감 시간 지나게', (b) {
                b.debugExpireDate();
                return null;
              }),
              MockAction('필름 24장 지급', (b) {
                b.debugGrantFilm();
                return null;
              }),
            ],
          ),
        ],
      ),
    );
  }
}
