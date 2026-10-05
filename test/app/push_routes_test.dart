import 'package:flutter_test/flutter_test.dart';
import 'package:phodam/app/routes.dart';
import 'package:phodam/app/push_routes.dart';

void main() {
  test('푸시 종류별로 열 화면을 정한다', () {
    expect(routeForPush({'type': 'date_revealed', 'date_id': 'd1'}),
        AppRoutes.diaryDetail('d1'));
    expect(routeForPush({'type': 'date_started', 'date_id': 'd1'}),
        AppRoutes.topic('d1'));
    expect(routeForPush({'type': 'partner_submitted', 'date_id': 'd1'}),
        AppRoutes.topic('d1'));
    expect(routeForPush({'type': 'deadline_soon', 'date_id': 'd1'}),
        AppRoutes.topic('d1'));
    expect(routeForPush({'type': 'unknown', 'date_id': 'd1'}), AppRoutes.home);
    expect(routeForPush({'type': 'date_started'}), isNull);
  });
}
