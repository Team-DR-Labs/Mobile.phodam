import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/home/presentation/home_page.dart';

part 'router.g.dart';

abstract final class AppRoutes {
  static const home = '/';
}

@riverpod
GoRouter router(Ref ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
