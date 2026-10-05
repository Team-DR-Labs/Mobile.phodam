import 'package:freezed_annotation/freezed_annotation.dart';

part 'sample_item.freezed.dart';
part 'sample_item.g.dart';

@freezed
abstract class SampleItem with _$SampleItem {
  const factory SampleItem({
    required int id,
    required String title,
    @Default('') String body,
  }) = _SampleItem;

  factory SampleItem.fromJson(Map<String, dynamic> json) =>
      _$SampleItemFromJson(json);
}
