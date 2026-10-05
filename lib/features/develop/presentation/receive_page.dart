import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/formatters.dart';
import '../../../core/widgets/countdown_text.dart';
import '../../../core/widgets/error_view.dart';
import 'receive_controller.dart';
import 'receive_tile.dart';

/// 제출 후 내 사진을 사진첩 '포담' 앨범으로 받는다.
class ReceivePage extends ConsumerWidget {
  const ReceivePage({super.key, required this.dateId});

  final String dateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(receiveControllerProvider(dateId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '홈으로',
          icon: const Icon(Icons.close),
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: const Text('사진 받기'),
      ),
      body: switch (state) {
        AsyncValue(:final value?) => _ReceiveBody(dateId: dateId, state: value),
        AsyncValue(:final error?) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(receiveControllerProvider(dateId)),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ReceiveBody extends ConsumerWidget {
  const _ReceiveBody({required this.dateId, required this.state});

  final String dateId;
  final ReceiveState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(receiveControllerProvider(dateId).notifier);
    final theme = Theme.of(context);
    final remaining = state.remaining.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: Text('${Formats.dateTime(state.deadline)}까지 받을 수 있어요'),
            subtitle: CountdownText(
              deadline: state.deadline,
              now: ref.watch(clockProvider),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '사진첩 "포담" 앨범에 저장돼요. 저장에 성공한 사진만 서버에서 지워지고, '
          '실패한 사진은 기한 안에 다시 받을 수 있어요.',
          style: theme.textTheme.bodySmall,
        ),
        if (state.permissionDenied) const _PermissionNotice(),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 3 / 4,
          ),
          itemCount: state.items.length,
          itemBuilder: (context, index) {
            final item = state.items[index];
            return ReceiveTile(
              item: item,
              onTap: state.running
                  ? null
                  : () => switch (item.status) {
                        ReceiveItemStatus.failed ||
                        ReceiveItemStatus.ackPending =>
                          controller.retry(item.photo.id),
                        ReceiveItemStatus.idle =>
                          controller.toggleSelect(item.photo.id),
                        _ => null,
                      },
            );
          },
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('receiveAll'),
          onPressed:
              state.running || remaining == 0 ? null : controller.receiveAll,
          child: Text(remaining == 0 ? '모두 받았어요' : '전체 받기 ($remaining장)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: state.running || !state.hasSelection
              ? null
              : controller.receiveSelected,
          child: const Text('선택한 사진 받기'),
        ),
      ],
    );
  }
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(top: 12),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          '사진첩 접근이 거부됐어요. 설정 > 포담 > 사진에서 접근을 허용한 뒤 다시 받아 주세요.',
        ),
      ),
    );
  }
}
