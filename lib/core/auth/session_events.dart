import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_events.g.dart';

/// 네트워크 계층이 "세션 만료"를 알리는 통로.
///
/// dio 와 인증 컨트롤러 사이의 provider 순환을 끊기 위해 둔다.
class SessionEvents {
  final _expired = StreamController<void>.broadcast();

  Stream<void> get onExpired => _expired.stream;

  void expire() => _expired.add(null);

  Future<void> dispose() => _expired.close();
}

@Riverpod(keepAlive: true)
SessionEvents sessionEvents(Ref ref) {
  final events = SessionEvents();
  ref.onDispose(events.dispose);
  return events;
}
