import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../auth/data/models/auth_models.dart';

part 'couple_models.freezed.dart';
part 'couple_models.g.dart';

@freezed
abstract class Couple with _$Couple {
  const factory Couple({
    required String id,
    required User partner,
    required DateTime connectedAt,
  }) = _Couple;

  factory Couple.fromJson(Map<String, dynamic> json) => _$CoupleFromJson(json);
}

@freezed
abstract class Invite with _$Invite {
  const factory Invite({required String code, required DateTime expiresAt}) =
      _Invite;

  factory Invite.fromJson(Map<String, dynamic> json) => _$InviteFromJson(json);
}
