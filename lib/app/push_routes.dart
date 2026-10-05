import 'routes.dart';

/// 푸시 data(`{type, date_id}`)를 열 화면 경로로 바꾼다(mvp-policy §12).
String? routeForPush(Map<String, dynamic> data) {
  final dateId = data['date_id'];
  if (dateId is! String || dateId.isEmpty) return null;
  return switch (data['type']) {
    'date_revealed' => AppRoutes.diaryDetail(dateId),
    'date_started' ||
    'partner_submitted' ||
    'deadline_soon' =>
      AppRoutes.topic(dateId),
    _ => AppRoutes.home,
  };
}
