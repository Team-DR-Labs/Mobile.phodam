import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/widgets/dami.dart';
import '../../../core/widgets/error_view.dart';
import '../data/social_sign_in.dart';
import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _devId = TextEditingController();
  final _nickname = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _devId.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(AuthController auth) action) async {
    setState(() => _busy = true);
    try {
      await action(ref.read(authControllerProvider.notifier));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = ref.watch(socialSignInProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            const Center(child: Dami(size: 160)),
            const SizedBox(height: 24),
            Text(
              '포담',
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '함께 담는 사진일기',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 40),
            if (social.appleAvailable)
              _LoginButton(
                label: 'Apple로 계속하기',
                icon: Icons.apple,
                onPressed: _busy
                    ? null
                    : () => _run((auth) => auth.signInWithApple()),
              ),
            if (social.googleAvailable)
              _LoginButton(
                label: 'Google로 계속하기',
                icon: Icons.g_mobiledata,
                onPressed: _busy
                    ? null
                    : () => _run((auth) => auth.signInWithGoogle()),
              ),
            if (Env.devToolsEnabled) _devLogin(theme),
          ],
        ),
      ),
    );
  }

  Widget _devLogin(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('개발용 로그인 (${Env.useMock ? 'mock' : Env.name})',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            TextField(
              key: const Key('devIdField'),
              controller: _devId,
              decoration: const InputDecoration(labelText: 'dev_id (예: alice)'),
              maxLength: 40,
            ),
            TextField(
              controller: _nickname,
              decoration: const InputDecoration(labelText: '닉네임 (선택)'),
              maxLength: 20,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      final devId = _devId.text.trim();
                      if (devId.isEmpty) return;
                      final nickname = _nickname.text.trim();
                      _run((auth) => auth.signInWithDev(
                            devId,
                            nickname: nickname.isEmpty ? null : nickname,
                          ));
                    },
              child: const Text('개발용 로그인'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
