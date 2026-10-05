import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'submit_photos.dart';

/// rune 기준으로 길이를 제한한다(이모지 등 서버 기준과 맞추기 위함).
class RuneLimitFormatter extends TextInputFormatter {
  const RuneLimitFormatter(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.text.runes.length > max ? oldValue : newValue;
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
