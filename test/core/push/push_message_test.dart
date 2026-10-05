import 'package:flutter_test/flutter_test.dart';
import 'package:phodam/app/push_routes.dart';
import 'package:phodam/app/routes.dart';
import 'package:phodam/core/push/local_notifier.dart';
import 'package:phodam/core/push/push_message.dart';

void main() {
  const data = {'type': 'date_started', 'date_id': 'd1'};

  test('제목이나 본문이 있으면 포그라운드 로컬 알림으로 보여준다', () {
    expect(const PushMessage(title: '데이트 시작', data: data).hasNotice, isTrue);
    expect(const PushMessage(body: '주제를 확인해 보세요').hasNotice, isTrue);
    expect(const PushMessage(title: ' ', data: data).hasNotice, isFalse);
    expect(const PushMessage(data: data).hasNotice, isFalse);
  });

  test('같은 데이트·종류의 알림은 같은 id 로 겹친다', () {
    const a = PushMessage(title: 'a', data: data);
    const b = PushMessage(title: 'b', data: data);
    const other =
        PushMessage(title: 'a', data: {'type': 'date_revealed', 'date_id': 'd1'});
    expect(a.noticeId, b.noticeId);
    expect(a.noticeId, isNot(other.noticeId));
    expect(a.noticeId, greaterThanOrEqualTo(0));
  });

  test('로컬 알림 payload 로 왕복해 같은 딥링크로 이동한다', () {
    final decoded = decodePushPayload(encodePushPayload(data));
    expect(decoded, data);
    expect(routeForPush(decoded), AppRoutes.topic('d1'));
  });

  test('payload 가 없거나 깨졌으면 빈 data(이동 없음)', () {
    expect(decodePushPayload(null), isEmpty);
    expect(decodePushPayload('{broken'), isEmpty);
    expect(decodePushPayload('[1,2]'), isEmpty);
    expect(routeForPush(decodePushPayload('{broken')), isNull);
  });

  test('채널 ID 는 서버·manifest 와 같은 podam_default', () {
    expect(LocalNotifier.channelId, 'podam_default');
    expect(LocalNotifier.channelName, '포담 알림');
  });
}
