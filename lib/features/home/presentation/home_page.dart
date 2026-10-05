import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dami.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../me/presentation/me_controller.dart';

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
            tooltip: '로그아웃',
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.read(meControllerProvider.notifier).reload(),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(child: Dami()),
            const SizedBox(height: 16),
            Text('${value?.user.nickname} · 남은 필름 ${value?.filmBalance}장'),
          ],
        ),
      ),
    );
  }
}
