import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/dami.dart';
import '../../camera/data/upload_queue.dart';
import 'receive_controller.dart';

/// 제출 직후 암실 연출: 대표 사진이 어둠 속에서 서서히 떠오른다(~3초).
class DevelopPage extends ConsumerStatefulWidget {
  const DevelopPage({super.key, required this.dateId, this.photoId});

  final String dateId;
  final String? photoId;

  @override
  ConsumerState<DevelopPage> createState() => _DevelopPageState();
}

class _DevelopPageState extends ConsumerState<DevelopPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _localPath() {
    final id = widget.photoId;
    if (id == null) return null;
    return ref.watch(uploadQueueProvider).value?.byId(id)?.filePath;
  }

  String? _representativeUrl() {
    final items =
        ref.watch(receiveControllerProvider(widget.dateId)).value?.items;
    return items
        ?.where((i) => i.photo.isRepresentative)
        .firstOrNull
        ?.photo
        .url;
  }

  @override
  Widget build(BuildContext context) {
    final localPath = _localPath();
    final url = localPath == null ? _representativeUrl() : null;
    return Scaffold(
      backgroundColor: AppColors.darkroom,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_controller.value);
            final done = _controller.isCompleted;
            return Column(
              children: [
                _Safelight(intensity: 1 - t * 0.6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      const Dami(size: 56),
                      const SizedBox(width: 12),
                      Text(
                        done ? '현상 완료! 잘 나왔어요.' : '다미가 현상하는 중…',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: Opacity(
                          opacity: t,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.matrix(developMatrix(t)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: AppImage(localPath: localPath, url: url),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: AnimatedOpacity(
                    opacity: done ? 1 : 0,
                    duration: const Duration(milliseconds: 400),
                    child: FilledButton(
                      onPressed: done
                          ? () => context.go(AppRoutes.receive(widget.dateId))
                          : null,
                      child: const Text('사진 받으러 가기'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// t=0 은 붉은 암실 속 어두운 상, t=1 은 원본.
List<double> developMatrix(double t) {
  const dark = <double>[
    0.45, 0.10, 0.05, 0, 10, //
    0.05, 0.12, 0.02, 0, 0,
    0.03, 0.05, 0.10, 0, 0,
    0, 0, 0, 1, 0,
  ];
  const identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];
  return [
    for (var i = 0; i < identity.length; i++)
      dark[i] + (identity[i] - dark[i]) * t,
  ];
}

class _Safelight extends StatelessWidget {
  const _Safelight({required this.intensity});

  final double intensity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 2.5,
          colors: [
            AppColors.safelight.withValues(alpha: 0.55 * intensity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
