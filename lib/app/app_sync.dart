import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/connectivity.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/camera/data/upload_queue.dart';
import '../features/me/presentation/me_controller.dart';

/// 앱 복귀·온라인 복귀·로그인 시 업로드 큐 재시도와 `/me` 갱신을 건다.
class AppSync extends ConsumerStatefulWidget {
  const AppSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppSync> createState() => _AppSyncState();
}

class _AppSyncState extends ConsumerState<AppSync> {
  late final AppLifecycleListener _lifecycle;

  bool get _signedIn => ref.read(authControllerProvider) == AuthStatus.signedIn;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onResume() {
    if (!_signedIn) return;
    ref.read(meControllerProvider.notifier).reload();
    _retryUploads();
  }

  void _retryUploads() {
    if (_signedIn) ref.read(uploadQueueProvider.notifier).process();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (next == AuthStatus.signedIn) _retryUploads();
    });
    ref.listen(onlineProvider, (previous, next) {
      if (next.value == true && previous?.value != true) _retryUploads();
    });
    return widget.child;
  }
}
