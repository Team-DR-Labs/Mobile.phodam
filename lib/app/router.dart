import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/camera/presentation/camera_page.dart';
import '../features/couple/presentation/couple_page.dart';
import '../features/date/presentation/topic_page.dart';
import '../features/date/presentation/waiting_page.dart';
import '../features/develop/presentation/develop_page.dart';
import '../features/develop/presentation/receive_page.dart';
import '../features/diary/presentation/diary_detail_page.dart';
import '../features/diary/presentation/diary_list_page.dart';
import '../features/submit/presentation/submit_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/me/presentation/me_controller.dart';
import 'redirect.dart';
import 'routes.dart';

part 'router.g.dart';

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.listen(meControllerProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      auth: ref.read(authControllerProvider),
      me: ref.read(meControllerProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.couple,
        builder: (context, state) => const CouplePage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/dates/:id/topic',
        builder: (context, state) =>
            TopicPage(dateId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dates/:id/camera',
        builder: (context, state) =>
            CameraPage(dateId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dates/:id/submit',
        builder: (context, state) =>
            SubmitPage(dateId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dates/:id/develop',
        builder: (context, state) => DevelopPage(
          dateId: state.pathParameters['id']!,
          photoId: state.uri.queryParameters['photo'],
        ),
      ),
      GoRoute(
        path: '/dates/:id/receive',
        builder: (context, state) =>
            ReceivePage(dateId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dates/:id/waiting',
        builder: (context, state) =>
            WaitingPage(dateId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.diary,
        builder: (context, state) => const DiaryListPage(),
      ),
      GoRoute(
        path: '/diary/:id',
        builder: (context, state) =>
            DiaryDetailPage(dateId: state.pathParameters['id']!),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
}
