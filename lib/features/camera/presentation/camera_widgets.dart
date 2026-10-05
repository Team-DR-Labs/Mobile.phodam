import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_image.dart';

const _amber = Color(0xFFFFB74D);

class CameraTopBar extends StatelessWidget {
  const CameraTopBar({super.key, required this.title, required this.filmBalance});

  final String title;
  final int filmBalance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
          FilmCounter(count: filmBalance),
        ],
      ),
    );
  }
}

/// 필름 카메라의 남은 매수 창.
class FilmCounter extends StatelessWidget {
  const FilmCounter({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('filmCounter'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        count.toString().padLeft(2, '0'),
        style: const TextStyle(
          color: _amber,
          fontSize: 20,
          fontFeatures: [FontFeature.tabularFigures()],
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class CameraNotice extends StatelessWidget {
  const CameraNotice({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox(height: 24);
    return SizedBox(
      height: 24,
      child: Text(text, style: const TextStyle(color: _amber)),
    );
  }
}

class CameraBottomBar extends StatelessWidget {
  const CameraBottomBar({
    super.key,
    required this.lastShot,
    required this.pendingCount,
    required this.shutterEnabled,
    required this.busy,
    required this.onShutter,
    required this.onPick,
  });

  final String? lastShot;
  final int pendingCount;
  final bool shutterEnabled;
  final bool busy;
  final VoidCallback onShutter;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Thumbnail(path: lastShot, pendingCount: pendingCount, onTap: onPick),
          ShutterButton(
            enabled: shutterEnabled,
            busy: busy,
            onPressed: onShutter,
          ),
          SizedBox(
            width: 64,
            child: TextButton(
              onPressed: onPick,
              child: const Text('고르기', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.path,
    required this.pendingCount,
    required this.onTap,
  });

  final String? path;
  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: path == null
                  ? const ColoredBox(color: Colors.white10)
                  : AppImage(localPath: path),
            ),
            if (pendingCount > 0)
              const Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.cloud_upload, size: 16, color: _amber),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ShutterButton extends StatelessWidget {
  const ShutterButton({
    super.key,
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: '셔터',
      child: GestureDetector(
        key: const Key('shutter'),
        onTap: enabled ? onPressed : null,
        child: Container(
          width: 84,
          height: 84,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? AppColors.caramel : Colors.white24,
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
