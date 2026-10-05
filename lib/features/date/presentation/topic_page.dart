import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/time/clock.dart';
import '../../../core/widgets/countdown_text.dart';
import '../../../core/widgets/dami.dart';
import '../../../core/widgets/error_view.dart';
import '../data/models/date_models.dart';
import 'date_controller.dart';

/// 내 주제와 마감까지 남은 시간. 상대 주제는 이 화면에서 절대 보여주지 않는다.
class TopicPage extends ConsumerWidget {
  const TopicPage({super.key, required this.dateId});

  final String dateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(dateDetailProvider(dateId));
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 주제')),
      body: date.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(dateDetailProvider(dateId)),
        ),
        data: (value) => _TopicBody(date: value),
      ),
    );
  }
}

class _TopicBody extends ConsumerStatefulWidget {
  const _TopicBody({required this.date});

  final DateView date;

  @override
  ConsumerState<_TopicBody> createState() => _TopicBodyState();
}

class _TopicBodyState extends ConsumerState<_TopicBody> {
  bool _joining = false;

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      await ref.read(dateActionsProvider).join(widget.date.id);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final theme = Theme.of(context);
    final now = ref.watch(clockProvider);
    final topic = date.me.topic;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DamiSays(
          topic == null
              ? '주제를 확인하면 촬영을 시작할 수 있어요.'
              : '같은 테마, 서로 다른 주제예요.\n상대 주제는 둘 다 제출하면 공개돼요.',
        ),
        const SizedBox(height: 24),
        Text('테마', style: theme.textTheme.labelLarge),
        Text(date.theme.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('내 주제', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(
                  topic?.title ?? '아직 확인하지 않았어요',
                  key: const Key('myTopic'),
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('제출 마감까지'),
          trailing: CountdownText(deadline: date.deadlineAt, now: now),
        ),
        ListTile(
          leading: const Icon(Icons.favorite_outline),
          title: Text(date.partner.user.nickname),
          trailing: Text(participantStatusLabel(date.partner.status)),
        ),
        const SizedBox(height: 16),
        ..._actions(date, now()),
      ],
    );
  }

  List<Widget> _actions(DateView date, DateTime now) {
    if (date.me.status == ParticipantStatus.assigned && date.isActive) {
      return [
        FilledButton(
          onPressed: _joining ? null : _join,
          child: const Text('참여하고 주제 확인하기'),
        ),
      ];
    }
    if (date.canShoot(now)) {
      return [
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.camera(date.id)),
          icon: const Icon(Icons.photo_camera),
          label: const Text('촬영하러 가기'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.push(AppRoutes.submit(date.id)),
          child: const Text('사진 고르고 제출하기'),
        ),
      ];
    }
    if (date.me.status == ParticipantStatus.submitted) {
      return [
        FilledButton(
          onPressed: () => context.push(AppRoutes.receive(date.id)),
          child: const Text('내 사진 받기'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.push(AppRoutes.waiting(date.id)),
          child: const Text('상대 상태 보기'),
        ),
      ];
    }
    return const [];
  }
}
