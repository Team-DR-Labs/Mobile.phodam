import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env.dart';
import '../core/widgets/error_view.dart';
import '../features/me/presentation/me_controller.dart';
import 'mock_backend.dart';

class MockAction {
  const MockAction(this.label, this.run);

  final String label;

  /// 결과 문구를 돌려주면 스낵바로 보여준다.
  final String? Function(MockBackend backend) run;
}

/// mock 환경에서만 보이는 "상대 행동 시뮬레이트" 버튼 묶음.
class MockDebugPanel extends ConsumerWidget {
  const MockDebugPanel({super.key, required this.actions, this.onDone});

  final List<MockAction> actions;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.useMock) return const SizedBox.shrink();
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.bug_report_outlined),
        title: const Text('개발용: 상대 행동 시뮬레이트'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in actions)
                  ActionChip(
                    label: Text(action.label),
                    onPressed: () => _run(context, ref, action),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _run(BuildContext context, WidgetRef ref, MockAction action) {
    try {
      final message = action.run(ref.read(mockBackendProvider));
      ref.read(meControllerProvider.notifier).reload();
      onDone?.call();
      showMessage(context, message ?? '${action.label} 완료');
    } catch (e) {
      showError(context, e);
    }
  }
}
