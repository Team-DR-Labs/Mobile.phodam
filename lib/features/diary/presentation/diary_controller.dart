import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/diary_repository.dart';
import '../data/models/diary_models.dart';

part 'diary_controller.freezed.dart';
part 'diary_controller.g.dart';

@freezed
abstract class DiaryPage with _$DiaryPage {
  const factory DiaryPage({
    required List<DiaryListItem> items,
    String? nextCursor,
    @Default(false) bool loadingMore,
  }) = _DiaryPage;
}

/// 일기 목록 무한 스크롤.
@riverpod
class DiaryListController extends _$DiaryListController {
  static const pageSize = 20;

  @override
  Future<DiaryPage> build() async {
    final page = await ref.watch(diaryRepositoryProvider).list(limit: pageSize);
    return DiaryPage(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(diaryRepositoryProvider)
          .list(cursor: cursor, limit: pageSize);
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.items],
          nextCursor: next.nextCursor,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (ref.mounted) state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }
}

@riverpod
Future<DiaryDetail> diaryDetail(Ref ref, String dateId) =>
    ref.watch(diaryRepositoryProvider).detail(dateId);

/// local_date 로 묶는다. 서버 정렬(started_at 내림차순)을 유지한다.
List<(String, List<DiaryListItem>)> groupByLocalDate(
  List<DiaryListItem> items,
) {
  final groups = <(String, List<DiaryListItem>)>[];
  for (final item in items) {
    if (groups.isNotEmpty && groups.last.$1 == item.localDate) {
      groups.last.$2.add(item);
    } else {
      groups.add((item.localDate, [item]));
    }
  }
  return groups;
}

String visibilityLabel(DiaryVisibility visibility) => switch (visibility) {
      DiaryVisibility.shared => '함께 공개',
      DiaryVisibility.waiting => '상대 기다리는 중',
      DiaryVisibility.private => '나만 보는 기록',
    };
