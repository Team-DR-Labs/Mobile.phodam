import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'submit_photos.dart';

/// 서버와 같은 기준(앞뒤 공백 제거 후 rune 수)으로 길이를 제한한다.
///
/// 넘치는 붙여넣기는 거부하지 않고 들어갈 만큼만 잘라 넣는다.
class RuneLimitFormatter extends TextInputFormatter {
  const RuneLimitFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (captionLength(newValue.text) <= max) return newValue;
    final old = oldValue.text;
    final start = oldValue.selection.isValid
        ? oldValue.selection.start
        : old.length;
    final end = oldValue.selection.isValid
        ? oldValue.selection.end
        : old.length;
    final prefix = old.substring(0, start);
    final suffix = old.substring(end);
    final text = newValue.text;
    final isInsertion =
        text.length >= prefix.length + suffix.length &&
        text.startsWith(prefix) &&
        text.endsWith(suffix);
    if (!isInsertion) return oldValue;
    final inserted = text
        .substring(prefix.length, text.length - suffix.length)
        .runes
        .toList();
    var keep = (max - captionLength(prefix + suffix)).clamp(0, inserted.length);
    String build(int n) =>
        prefix + String.fromCharCodes(inserted.take(n)) + suffix;
    while (keep > 0 && captionLength(build(keep)) > max) {
      keep--;
    }
    final head = prefix + String.fromCharCodes(inserted.take(keep));
    return TextEditingValue(
      text: head + suffix,
      selection: TextSelection.collapsed(offset: head.length),
    );
  }
}

class CaptionField extends StatelessWidget {
  const CaptionField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        key: const Key('captionField'),
        controller: controller,
        minLines: 3,
        maxLines: 6,
        inputFormatters: const [RuneLimitFormatter(captionMaxRunes)],
        decoration: InputDecoration(
          hintText: '짧은 글을 남겨 보세요 (선택)',
          counterText: '${captionLength(value.text)}/$captionMaxRunes',
        ),
      ),
    );
  }
}
