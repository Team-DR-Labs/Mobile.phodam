import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/connectivity.dart';
import '../core/push/push_service.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/camera/data/upload_queue.dart';
import '../features/me/presentation/me_controller.dart';
import 'push_routes.dart';
import 'router.dart';

/// 앱 복귀·온라인 복귀·로그인 시 업로드 큐 재시도와 `/me` 갱신을 걸고, 푸시를 연결한다.
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
    _initPush();
  }

  Future<void> _initPush() async {
    final push = ref.read(pushServiceProvider);
    await push.init(
      onForeground: (_) {
        if (_signedIn) ref.read(meControllerProvider.notifier).reload();
      },
      onOpen: (data) {
        final route = routeForPush(data);
        if (route != null) ref.read(routerProvider).go(route);
      },
    );
    if (_signedIn) await push.registerToken();
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
      if (next != AuthStatus.signedIn) return;
      _retryUploads();
      ref.read(pushServiceProvider).registerToken();
    });
    ref.listen(onlineProvider, (previous, next) {
      if (next.value == true && previous?.value != true) _retryUploads();
    });
    return widget.child;
  }
}
