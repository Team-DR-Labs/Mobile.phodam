import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 캐릭터 다미.
class Dami extends StatelessWidget {
  const Dami({super.key, this.size = 160});

  static const asset = 'assets/images/dami.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.caramel, width: 3),
      ),
      child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
    );
  }
}

/// 다미가 말하는 말풍선.
class DamiSays extends StatelessWidget {
  const DamiSays(this.message, {super.key, this.size = 72});

  final String message;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Dami(size: size),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(message, style: theme.textTheme.bodyLarge),
          ),
        ),
      ],
    );
  }
}
