import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/time/clock.dart';
import '../../../core/widgets/countdown_text.dart';
import '../../../core/widgets/error_view.dart';
import '../../date/data/models/date_models.dart';
import '../../date/presentation/date_controller.dart';
import '../../me/data/models/me.dart';
import 'home_stage.dart';

/// 진행 중 데이트 상태와 다음 행동.
class HomeDateCard extends ConsumerStatefulWidget {
  const HomeDateCard({super.key, required this.me, required this.stage});

  final Me me;
  final HomeStage stage;

  @override
  ConsumerState<HomeDateCard> createState() => _HomeDateCardState();
}

class _HomeDateCardState extends ConsumerState<HomeDateCard> {
  bool _busy = false;

  Future<void> _run(Future<DateView> Function(DateActions a) action) async {
    setState(() => _busy = true);
    try {
      final date = await action(ref.read(dateActionsProvider));
      if (mounted) context.push(AppRoutes.topic(date.id));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.me.currentDate;
    if (widget.stage == HomeStage.noDate || date == null) {
      return FilledButton.icon(
        onPressed: _busy ? null : () => _run((a) => a.start()),
        icon: const Icon(Icons.favorite),
        label: const Text('데이트 시작하기'),
      );
    }
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('진행 중인 데이트', style: theme.textTheme.labelLarge),
            Text(date.theme.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            _row(Icons.timer_outlined, '마감까지',
                CountdownText(deadline: date.deadlineAt, now: ref.watch(clockProvider))),
            _row(Icons.person_outline, '나',
                Text('${participantStatusLabel(date.me.status)} · ${date.me.shotCount}장')),
            _row(Icons.favorite_outline, date.partner.user.nickname,
                Text(participantStatusLabel(date.partner.status))),
            const SizedBox(height: 12),
            ..._actions(date),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, Widget trailing) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            trailing,
          ],
        ),
      );

  List<Widget> _actions(DateView date) {
    const gap = SizedBox(height: 8);
    return switch (widget.stage) {
      HomeStage.needJoin => [
          FilledButton(
            onPressed: _busy ? null : () => _run((a) => a.join(date.id)),
            child: const Text('참여하고 주제 확인하기'),
          ),
        ],
      HomeStage.shooting => [
          FilledButton.icon(
            onPressed: () => context.push(AppRoutes.camera(date.id)),
            icon: const Icon(Icons.photo_camera),
            label: const Text('촬영하기'),
          ),
          gap,
          OutlinedButton(
            onPressed: () => context.push(AppRoutes.submit(date.id)),
            child: const Text('사진 고르고 제출하기'),
          ),
          TextButton(
            onPressed: () => context.push(AppRoutes.topic(date.id)),
            child: const Text('내 주제 다시 보기'),
          ),
        ],
      HomeStage.submitted => [
          FilledButton(
            onPressed: () => context.push(AppRoutes.receive(date.id)),
            child: const Text('내 사진 받기'),
          ),
          gap,
          OutlinedButton(
            onPressed: () => context.push(AppRoutes.waiting(date.id)),
            child: const Text('상대 기다리는 중'),
          ),
        ],
      HomeStage.noDate => const [],
    };
  }
}
