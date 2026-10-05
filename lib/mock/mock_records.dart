part of 'mock_backend.dart';

// 가짜 서버의 내부 레코드. 서버 DB 행을 흉내 내므로 내부에서만 변경한다.

class _MUser {
  _MUser({required this.id, required this.devId, required this.nickname});

  final String id;
  final String devId;
  String nickname;
  int filmBalance = MockBackend.rollSize;

  User toUser() => User(id: id, nickname: nickname);
}

class _MInvite {
  _MInvite({required this.code, required this.ownerId, required this.expiresAt});

  final String code;
  final String ownerId;
  final DateTime expiresAt;
  bool used = false;
  bool revoked = false;
}

class _MCouple {
  _MCouple({
    required this.id,
    required this.userA,
    required this.userB,
    required this.connectedAt,
  });

  final String id;
  final String userA;
  final String userB;
  final DateTime connectedAt;

  String partnerOf(String userId) => userId == userA ? userB : userA;
}

class _MParticipant {
  _MParticipant({required this.userId, required this.topic, required this.status});

  final String userId;
  final Topic topic;
  ParticipantStatus status;
  DateTime? joinedAt;
  DateTime? submittedAt;
  DateTime? receiveDeadlineAt;
  int shotCount = 0;
  String? representativePhotoId;
  String? caption;
}

class _MDate {
  _MDate({
    required this.id,
    required this.coupleId,
    required this.theme,
    required this.startedBy,
    required this.startedAt,
    required this.participants,
  }) : deadlineAt = startedAt.add(MockBackend.dateDuration);

  final String id;
  final String coupleId;
  final DateTheme theme;
  final String startedBy;
  final DateTime startedAt;
  DateTime deadlineAt;
  DateStatus status = DateStatus.inProgress;
  DateTime? revealedAt;
  final Map<String, _MParticipant> participants;
}

class _MPhoto {
  _MPhoto({
    required this.id,
    required this.dateId,
    required this.userId,
    required this.createdAt,
  });

  final String id;
  final String dateId;
  final String userId;
  final DateTime createdAt;
  PhotoStatus status = PhotoStatus.reserved;
  bool isRepresentative = false;
  DateTime? uploadedAt;
  DateTime? receivedAt;

  /// 저장된 객체 위치. `file://...` 또는 `asset:...`.
  String? objectUrl;

  Photo toPhoto() => Photo(
        id: id,
        dateId: dateId,
        status: status,
        isRepresentative: isRepresentative,
        createdAt: createdAt,
        uploadedAt: uploadedAt,
        receivedAt: receivedAt,
      );

  PhotoWithUrl withUrl(DateTime expiresAt) => PhotoWithUrl(
        id: id,
        dateId: dateId,
        status: status,
        isRepresentative: isRepresentative,
        createdAt: createdAt,
        uploadedAt: uploadedAt,
        receivedAt: receivedAt,
        url: objectUrl!,
        urlExpiresAt: expiresAt,
      );
}

const _seedThemes = <(String, List<String>)>[
  ('온기', ['따뜻한 색', '마음이 편해지는 장면', '손끝의 온도']),
  ('오늘의 빛', ['창가에 든 빛', '그림자 놀이', '반짝이는 것']),
  ('작은 것들', ['손바닥보다 작은 것', '발밑의 풍경', '숨은 디테일']),
  ('우리 동네', ['자주 지나는 길', '처음 본 간판', '동네의 색']),
  ('맛있는 기억', ['오늘의 한 입', '테이블 위 풍경', '함께 나눈 것']),
  ('하늘', ['올려다본 하늘', '하늘과 건물', '구름의 모양']),
  ('색깔 찾기', ['빨간 것', '파란 것', '노란 것']),
  ('웃음', ['웃게 만든 것', '상대의 웃음', '귀여운 순간']),
  ('여행자처럼', ['처음 가본 곳', '길 위의 표지', '돌아보고 싶은 곳']),
  ('기다림', ['기다리는 동안', '창밖 풍경', '시계가 있는 장면']),
];
