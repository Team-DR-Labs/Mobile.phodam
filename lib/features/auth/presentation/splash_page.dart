import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dami.dart';
import '../../../core/widgets/error_view.dart';
import '../../me/presentation/me_controller.dart';
import 'auth_controller.dart';

/// 토큰 확인과 `/me` 로딩 중에 보이는 화면.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Dami(size: 140),
              const SizedBox(height: 24),
              if (me.hasError && !me.hasValue) ...[
                ErrorView(
                  error: me.error!,
                  onRetry: () =>
                      ref.read(meControllerProvider.notifier).reload(),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  child: const Text('로그아웃'),
                ),
              ] else
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
