import 'package:flutter/material.dart';

import '../../../core/widgets/app_image.dart';
import 'receive_controller.dart';

class ReceiveTile extends StatelessWidget {
  const ReceiveTile({super.key, required this.item, required this.onTap});

  final ReceiveItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: Key('receive-${item.photo.id}'),
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppImage(url: item.photo.url),
          ),
          if (item.photo.isRepresentative)
            const Positioned(
              left: 4,
              top: 4,
              child: _Badge(label: '대표'),
            ),
          Positioned(right: 4, top: 4, child: _statusIcon(scheme)),
        ],
      ),
    );
  }

  Widget _statusIcon(ColorScheme scheme) => switch (item.status) {
        ReceiveItemStatus.saved =>
          const Icon(Icons.check_circle, color: Colors.lightGreenAccent),
        ReceiveItemStatus.working => const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ReceiveItemStatus.failed => const _Badge(label: '실패 · 다시 받기'),
        ReceiveItemStatus.ackPending => const _Badge(label: '확인 재시도'),
        ReceiveItemStatus.idle => Icon(
            item.selected ? Icons.check_box : Icons.check_box_outline_blank,
            color: Colors.white,
          ),
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}
