import 'package:flutter/material.dart';

import '../../../core/widgets/app_image.dart';
import 'submit_photos.dart';

/// 대표 사진 선택 그리드. 보기·선택만 가능하다.
class PhotoPickerGrid extends StatelessWidget {
  const PhotoPickerGrid({
    super.key,
    required this.photos,
    required this.selectedId,
    required this.onSelect,
  });

  final List<SelectablePhoto> photos;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 3 / 4,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return _PickerTile(
          photo: photo,
          selected: photo.photoId == selectedId,
          onTap: photo.uploaded ? () => onSelect(photo.photoId) : null,
        );
      },
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.photo,
    required this.selected,
    required this.onTap,
  });

  final SelectablePhoto photo;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: Key('pick-${photo.photoId}'),
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppImage(localPath: photo.localPath, url: photo.url),
          ),
          if (!photo.uploaded)
            Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                '업로드 중',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          if (selected)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.primary, width: 4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.check_circle, color: scheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
