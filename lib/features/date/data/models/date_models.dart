import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../auth/data/models/auth_models.dart';

part 'date_models.freezed.dart';
part 'date_models.g.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum DateStatus { inProgress, revealed, expired }

@JsonEnum(fieldRename: FieldRename.snake)
enum ParticipantStatus { assigned, joined, submitted }

/// 서버 스키마 `Theme`. Flutter 의 Theme 와 겹치지 않게 이름을 바꿨다.
@freezed
abstract class DateTheme with _$DateTheme {
  const factory DateTheme({required String id, required String title}) =
      _DateTheme;

  factory DateTheme.fromJson(Map<String, dynamic> json) =>
      _$DateThemeFromJson(json);
}

@freezed
abstract class Topic with _$Topic {
  const factory Topic({required String id, required String title}) = _Topic;

  factory Topic.fromJson(Map<String, dynamic> json) => _$TopicFromJson(json);
}

@freezed
abstract class MyParticipation with _$MyParticipation {
  const factory MyParticipation({
    required ParticipantStatus status,
    Topic? topic,
    DateTime? joinedAt,
    DateTime? submittedAt,
    DateTime? receiveDeadlineAt,
    required int shotCount,
  }) = _MyParticipation;

  factory MyParticipation.fromJson(Map<String, dynamic> json) =>
      _$MyParticipationFromJson(json);
}

@freezed
abstract class PartnerParticipation with _$PartnerParticipation {
  const factory PartnerParticipation({
    required User user,
    required ParticipantStatus status,

    /// 데이트가 revealed 일 때만 값이 있다. 앱은 데이트 진행 화면에서 쓰지 않는다.
    Topic? topic,
  }) = _PartnerParticipation;

  factory PartnerParticipation.fromJson(Map<String, dynamic> json) =>
      _$PartnerParticipationFromJson(json);
}

@freezed
abstract class DateView with _$DateView {
  const DateView._();

  const factory DateView({
    required String id,
    required DateStatus status,
    required DateTheme theme,
    required bool startedByMe,
    required DateTime startedAt,
    required DateTime deadlineAt,
    DateTime? revealedAt,
    required MyParticipation me,
    required PartnerParticipation partner,
  }) = _DateView;

  factory DateView.fromJson(Map<String, dynamic> json) =>
      _$DateViewFromJson(json);

  bool get isActive => status == DateStatus.inProgress;

  /// 촬영·제출이 가능한 상태(정책 §6, §7). 기한은 [now] 로 함께 판정한다.
  bool canShoot(DateTime now) =>
      isActive &&
      now.isBefore(deadlineAt) &&
      me.status == ParticipantStatus.joined;
}
