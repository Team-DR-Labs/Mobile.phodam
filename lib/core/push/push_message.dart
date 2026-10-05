import 'dart:convert';

/// 수신한 푸시 한 건. 서버가 notification(title/body)과 data(type, date_id)를 함께 보낸다.
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  /// 앱 사용 중에 받았을 때 로컬 알림으로 보여줄 내용이 있는지.
  bool get hasNotice =>
      (title?.trim().isNotEmpty ?? false) || (body?.trim().isNotEmpty ?? false);

  /// 같은 데이트·종류의 알림은 하나로 겹쳐 보이도록 고정 id 를 쓴다.
  int get noticeId =>
      Object.hash(data['type'], data['date_id']) & 0x7fffffff;
}

/// 로컬 알림 payload ↔ data. 탭하면 같은 딥링크 로직으로 이동한다.
String encodePushPayload(Map<String, dynamic> data) => jsonEncode(data);

Map<String, dynamic> decodePushPayload(String? payload) {
  if (payload == null || payload.isEmpty) return const {};
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : const {};
  } on FormatException {
    return const {};
  }
}
