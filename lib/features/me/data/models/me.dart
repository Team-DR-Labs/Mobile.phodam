import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../auth/data/models/auth_models.dart';
import '../../../couple/data/models/couple_models.dart';
import '../../../date/data/models/date_models.dart';

part 'me.freezed.dart';
part 'me.g.dart';

/// `GET /me`. 앱 상태의 중심이다.
@freezed
abstract class Me with _$Me {
  const factory Me({
    required User user,
    required int filmBalance,
    Couple? couple,
    DateView? currentDate,
  }) = _Me;

  factory Me.fromJson(Map<String, dynamic> json) => _$MeFromJson(json);
}
