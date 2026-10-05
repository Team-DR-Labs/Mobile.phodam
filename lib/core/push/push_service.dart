import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/me/data/me_repository.dart';
import '../logger/app_logger.dart';
import 'push_message.dart';

part 'push_service.g.dart';

typedef PushDataHandler = void Function(Map<String, dynamic> data);
typedef PushMessageHandler = void Function(PushMessage message);

/// FCM. Firebase 설정 파일이 없으면 초기화에 실패하고 조용히 건너뛴다.
class PushService {
  PushService({required this._logger, required this._meRepository});

  final Logger _logger;
  final MeRepository _meRepository;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _ready = false;

  bool get isReady => _ready;

  /// 앱 시작 시 한 번. [onForeground] 는 앱 사용 중 수신, [onOpen] 은 알림 탭.
  /// [isSignedIn] 이 false 면 토큰 갱신 이벤트를 서버에 등록하지 않는다
  /// (로그인 후 [registerToken] 이 등록한다).
  Future<void> init({
    required PushMessageHandler onForeground,
    required PushDataHandler onOpen,
    required bool Function() isSignedIn,
  }) async {
    if (_ready) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      _logger.i('Firebase 설정이 없어 푸시를 건너뛴다: $e');
      return;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      _subscriptions
        ..add(FirebaseMessaging.onMessage.listen(
          (m) => onForeground(
            PushMessage(
              title: m.notification?.title,
              body: m.notification?.body,
              data: m.data,
            ),
          ),
        ))
        ..add(FirebaseMessaging.onMessageOpenedApp
            .listen((m) => onOpen(m.data)))
        ..add(messaging.onTokenRefresh.listen((token) {
          if (isSignedIn()) _register(token);
        }));
      _ready = true;
      final initial = await messaging.getInitialMessage();
      if (initial != null) onOpen(initial.data);
    } catch (e) {
      _logger.w('푸시 초기화 실패', error: e);
    }
  }

  /// 로그인 후 기기 토큰을 서버에 등록한다(`PUT /me/devices`, 멱등).
  Future<void> registerToken() async {
    if (!_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
    } catch (e) {
      _logger.w('FCM 토큰을 가져오지 못함', error: e);
    }
  }

  Future<void> _register(String token) async {
    try {
      await _meRepository.registerDevice(
        fcmToken: token,
        platform: Platform.isIOS ? DevicePlatform.ios : DevicePlatform.android,
      );
    } catch (e) {
      _logger.w('기기 토큰 등록 실패', error: e);
    }
  }

  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
  }
}

@Riverpod(keepAlive: true)
PushService pushService(Ref ref) {
  final service = PushService(
    logger: ref.watch(appLoggerProvider),
    meRepository: ref.watch(meRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
}
