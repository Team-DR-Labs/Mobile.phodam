import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/time/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/dami.dart';
import '../../../core/widgets/error_view.dart';
import '../data/models/diary_models.dart';
import 'diary_controller.dart';
import 'visibility_badge.dart';

class DiaryListPage extends ConsumerStatefulWidget {
  const DiaryListPage({super.key});

  @override
  ConsumerState<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends ConsumerState<DiaryListPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 400) {
      ref
          .read(diaryListControllerProvider.notifier)
          .loadMore()
          .catchError((Object e) {
        if (mounted) showError(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(diaryListControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('우리의 일기')),
      body: switch (page) {
        AsyncValue(:final value?) => RefreshIndicator(
            onRefresh: () => ref.refresh(diaryListControllerProvider.future),
            child: value.items.isEmpty ? const _Empty() : _list(value),
          ),
        AsyncValue(:final error?) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(diaryListControllerProvider),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _list(DiaryPage page) {
    final groups = groupByLocalDate(page.items);
    final theme = Theme.of(context);
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final (date, items) in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              Formats.localDate(date),
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (final item in items) _DiaryTile(item: item),
        ],
        if (page.loadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _DiaryTile extends StatelessWidget {
  const _DiaryTile({required this.item});

  final DiaryListItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push(AppRoutes.diaryDetail(item.dateId)),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 56,
          child: AppImage(url: item.thumbnailUrl),
        ),
      ),
      title: Text(item.theme.title),
      trailing: VisibilityBadge(visibility: item.visibility),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: const [
        SizedBox(height: 48),
        Center(child: Dami(size: 120)),
        SizedBox(height: 16),
        Text('아직 남긴 일기가 없어요.\n데이트를 시작해 첫 장을 담아 보세요.',
            textAlign: TextAlign.center),
      ],
    );
  }
}
