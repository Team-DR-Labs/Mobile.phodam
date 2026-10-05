import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/time/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/error_view.dart';
import '../data/models/diary_models.dart';
import 'diary_controller.dart';
import 'visibility_badge.dart';

/// 공동 공개면 두 사람의 사진·글·주제를 나란히, 아니면 내 기록만 보여준다.
class DiaryDetailPage extends ConsumerWidget {
  const DiaryDetailPage({super.key, required this.dateId});

  final String dateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(diaryDetailProvider(dateId));
    return Scaffold(
      appBar: AppBar(title: const Text('일기')),
      body: switch (detail) {
        AsyncValue(:final value?) => _DetailBody(detail: value),
        AsyncValue(:final error?) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(diaryDetailProvider(dateId)),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final DiaryDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shared = detail.visibility == DiaryVisibility.shared;
    // 공동 공개가 아니면 응답에 상대 기록이 섞여 와도 내 것만 보여준다.
    final entries =
        shared ? detail.entries : detail.entries.where((e) => e.isMe).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(Formats.localDate(detail.localDate),
            style: theme.textTheme.labelLarge),
        Row(
          children: [
            Expanded(
              child: Text(detail.theme.title,
                  style: theme.textTheme.headlineSmall),
            ),
            VisibilityBadge(visibility: detail.visibility),
          ],
        ),
        const SizedBox(height: 16),
        if (shared)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, entry) in entries.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: DiaryEntryCard(entry: entry)),
              ],
            ],
          )
        else
          for (final entry in entries) DiaryEntryCard(entry: entry),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.receive(detail.dateId)),
          icon: const Icon(Icons.download_outlined),
          label: const Text('내 사진 받기'),
        ),
      ],
    );
  }
}

class DiaryEntryCard extends StatelessWidget {
  const DiaryEntryCard({super.key, required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('entry-${entry.author.id}'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(aspectRatio: 3 / 4, child: AppImage(url: entry.photoUrl)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.isMe ? '나' : entry.author.nickname,
                    style: theme.textTheme.labelLarge),
                Text(entry.topic.title, style: theme.textTheme.titleMedium),
                if (entry.caption != null) ...[
                  const SizedBox(height: 6),
                  Text(entry.caption!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
