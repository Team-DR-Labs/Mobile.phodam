import 'package:flutter/material.dart';

import '../data/models/diary_models.dart';
import 'diary_controller.dart';

class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({super.key, required this.visibility});

  final DiaryVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (visibility) {
      DiaryVisibility.shared => (scheme.primary, scheme.onPrimary),
      DiaryVisibility.waiting =>
        (scheme.secondaryContainer, scheme.onSecondaryContainer),
      DiaryVisibility.private =>
        (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        visibilityLabel(visibility),
        style: TextStyle(color: foreground, fontSize: 12),
      ),
    );
  }
}
