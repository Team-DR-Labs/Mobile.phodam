import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../auth/data/models/auth_models.dart';
import '../../../date/data/models/date_models.dart';

part 'diary_models.freezed.dart';
part 'diary_models.g.dart';

/// shared=공동 공개, waiting=내가 제출하고 상대 대기, private=만료되어 나만 보는 기록.
@JsonEnum(fieldRename: FieldRename.snake)
enum DiaryVisibility { shared, waiting, private }

@freezed
abstract class DiaryListItem with _$DiaryListItem {
  const factory DiaryListItem({
    required String dateId,

    /// started_at 의 Asia/Seoul 날짜 `YYYY-MM-DD`.
    required String localDate,
    required DateTheme theme,
    required DiaryVisibility visibility,
    required DateTime startedAt,
    required String thumbnailUrl,
    required DateTime thumbnailUrlExpiresAt,
  }) = _DiaryListItem;

  factory DiaryListItem.fromJson(Map<String, dynamic> json) =>
      _$DiaryListItemFromJson(json);
}

@freezed
abstract class DiaryList with _$DiaryList {
  const factory DiaryList({
    required List<DiaryListItem> items,
    String? nextCursor,
  }) = _DiaryList;

  factory DiaryList.fromJson(Map<String, dynamic> json) =>
      _$DiaryListFromJson(json);
}

@freezed
abstract class DiaryEntry with _$DiaryEntry {
  const factory DiaryEntry({
    required User author,
    required bool isMe,
    required Topic topic,
    String? caption,
    required String photoUrl,
    required DateTime photoUrlExpiresAt,
    required DateTime submittedAt,
  }) = _DiaryEntry;

  factory DiaryEntry.fromJson(Map<String, dynamic> json) =>
      _$DiaryEntryFromJson(json);
}

@freezed
abstract class DiaryDetail with _$DiaryDetail {
  const factory DiaryDetail({
    required String dateId,
    required String localDate,
    required DateTheme theme,
    required DiaryVisibility visibility,
    required DateTime startedAt,

    /// shared 면 2개(내 것 먼저), 그 외에는 내 것 1개.
    required List<DiaryEntry> entries,
  }) = _DiaryDetail;

  factory DiaryDetail.fromJson(Map<String, dynamic> json) =>
      _$DiaryDetailFromJson(json);
}
