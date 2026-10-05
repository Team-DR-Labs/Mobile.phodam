import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/time/clock.dart';
import '../../../core/widgets/countdown_text.dart';
import '../../../core/widgets/dami.dart';
import '../../../core/widgets/error_view.dart';
import '../../../mock/mock_backend.dart';
import '../../../mock/mock_debug_panel.dart';
import '../data/models/date_models.dart';
import 'date_controller.dart';

/// 내가 제출한 뒤 상대 제출을 기다리는 화면. 30초마다 상태를 다시 읽는다.
class WaitingPage extends ConsumerStatefulWidget {
  const WaitingPage({super.key, required this.dateId});

  final String dateId;

  @override
  ConsumerState<WaitingPage> createState() => _WaitingPageState();
}

class _WaitingPageState extends ConsumerState<WaitingPage> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _refresh() => ref.invalidate(dateDetailProvider(widget.dateId));

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(dateDetailProvider(widget.dateId));
    return Scaffold(
      appBar: AppBar(title: const Text('상대 기다리는 중')),
      body: switch (date) {
        AsyncValue(:final value?) => RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: _WaitingBody(date: value, onChanged: _refresh),
          ),
        AsyncValue(:final error?) => ErrorView(error: error, onRetry: _refresh),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _WaitingBody extends ConsumerWidget {
  const _WaitingBody({required this.date, required this.onChanged});

  final DateView date;
  final VoidCallback onChanged;

  String get _message => switch (date.status) {
        DateStatus.revealed => '둘 다 제출했어요! 서로의 사진을 확인해 보세요.',
        DateStatus.expired =>
          '마감까지 ${date.partner.user.nickname}님이 제출하지 않아 데이트가 끝났어요.\n내 기록은 일기에서 나만 볼 수 있어요.',
        DateStatus.inProgress =>
          '제출 완료! ${date.partner.user.nickname}님이 제출하면 함께 공개돼요.',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DamiSays(_message),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.check_circle_outline),
          title: const Text('나'),
          trailing: Text(participantStatusLabel(date.me.status)),
        ),
        ListTile(
          leading: const Icon(Icons.favorite_outline),
          title: Text(date.partner.user.nickname),
          trailing: Text(participantStatusLabel(date.partner.status)),
        ),
        if (date.isActive)
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('마감까지'),
            trailing: CountdownText(
              deadline: date.deadlineAt,
              now: ref.watch(clockProvider),
            ),
          ),
        const SizedBox(height: 16),
        if (date.status == DateStatus.revealed)
          FilledButton(
            onPressed: () => context.push(AppRoutes.diaryDetail(date.id)),
            child: const Text('함께 공개된 일기 보기'),
          ),
        if (date.status == DateStatus.expired)
          FilledButton(
            onPressed: () => context.push(AppRoutes.diaryDetail(date.id)),
            child: const Text('내 기록 보기'),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.push(AppRoutes.receive(date.id)),
          child: const Text('내 사진 받기'),
        ),
        const SizedBox(height: 24),
        MockDebugPanel(
          onDone: onChanged,
          actions: [
            MockAction('상대가 제출', (b) {
              b.debugPartnerSubmit();
              return null;
            }),
            MockAction('마감 시간 지나게', (b) {
              b.debugExpireDate();
              return null;
            }),
          ],
        ),
      ],
    );
  }
}
