import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../logger/app_logger.dart';
import 'push_message.dart';

part 'local_notifier.g.dart';

/// 앱 사용 중(포그라운드) 받은 푸시를 기기 알림으로 보여준다(Android).
///
/// FCM 은 포그라운드에서 알림을 띄우지 않으므로 직접 표시한다.
class LocalNotifier {
  LocalNotifier(this._logger);

  /// 서버가 Android 알림에 지정하는 채널, manifest 기본 채널과 같아야 한다.
  static const channelId = 'podam_default';
  static const channelName = '포담 알림';

  /// `android/app/src/main/res/drawable/ic_stat_podam.xml` (흰색 단색).
  static const smallIcon = 'ic_stat_podam';

  final Logger _logger;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// 채널을 만들고 탭 처리기를 건다. Android 외 플랫폼은 아무것도 하지 않는다.
  Future<void> init({
    required void Function(Map<String, dynamic> data) onTap,
  }) async {
    if (_ready || !Platform.isAndroid) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(smallIcon),
        ),
        onDidReceiveNotificationResponse: (response) =>
            onTap(decodePushPayload(response.payload)),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              channelName,
              importance: Importance.high,
            ),
          );
      _ready = true;
      // 앱이 꺼진 뒤 로컬 알림을 탭해 실행된 경우.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
        onTap(decodePushPayload(response.payload));
      }
    } catch (e) {
      _logger.w('로컬 알림 초기화 실패', error: e);
    }
  }

  Future<void> show(PushMessage message) async {
    if (!_ready || !message.hasNotice) return;
    try {
      await _plugin.show(
        id: message.noticeId,
        title: message.title,
        body: message.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
            icon: smallIcon,
          ),
        ),
        payload: encodePushPayload(message.data),
      );
    } catch (e) {
      _logger.w('로컬 알림 표시 실패', error: e);
    }
  }
}

@Riverpod(keepAlive: true)
LocalNotifier localNotifications(Ref ref) =>
    LocalNotifier(ref.watch(appLoggerProvider));
