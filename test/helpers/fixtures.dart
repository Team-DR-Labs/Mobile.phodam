import 'package:phodam/features/auth/data/models/auth_models.dart';
import 'package:phodam/features/camera/data/models/photo_models.dart';
import 'package:phodam/features/couple/data/models/couple_models.dart';
import 'package:phodam/features/date/data/models/date_models.dart';
import 'package:phodam/features/me/data/models/me.dart';

final t0 = DateTime.utc(2026, 10, 5, 6);

const alice = User(id: 'u-alice', nickname: '앨리스');
const bob = User(id: 'u-bob', nickname: '밥');

Couple couple() => Couple(id: 'c1', partner: bob, connectedAt: t0);

DateView dateView({
  String id = 'd1',
  DateStatus status = DateStatus.inProgress,
  ParticipantStatus myStatus = ParticipantStatus.joined,
  ParticipantStatus partnerStatus = ParticipantStatus.assigned,
  Topic? partnerTopic,
  int shotCount = 0,
  DateTime? startedAt,
}) {
  final start = startedAt ?? t0;
  return DateView(
    id: id,
    status: status,
    theme: const DateTheme(id: 'th1', title: '온기'),
    startedByMe: true,
    startedAt: start,
    deadlineAt: start.add(const Duration(hours: 72)),
    me: MyParticipation(
      status: myStatus,
      topic: myStatus == ParticipantStatus.assigned
          ? null
          : const Topic(id: 'tp1', title: '따뜻한 색'),
      submittedAt: myStatus == ParticipantStatus.submitted ? start : null,
      receiveDeadlineAt: myStatus == ParticipantStatus.submitted
          ? start.add(const Duration(days: 7))
          : null,
      shotCount: shotCount,
    ),
    partner: PartnerParticipation(
      user: bob,
      status: partnerStatus,
      topic: partnerTopic,
    ),
  );
}

Me me({int film = 24, bool withCouple = true, DateView? current}) => Me(
      user: alice,
      filmBalance: film,
      couple: withCouple ? couple() : null,
      currentDate: current,
    );

PhotoWithUrl photoWithUrl(
  String id, {
  String dateId = 'd1',
  PhotoStatus status = PhotoStatus.uploaded,
  bool representative = false,
  DateTime? receivedAt,
}) =>
    PhotoWithUrl(
      id: id,
      dateId: dateId,
      status: status,
      isRepresentative: representative,
      createdAt: t0,
      uploadedAt: t0,
      receivedAt: receivedAt,
      url: 'https://storage.test/$id.jpg',
      urlExpiresAt: t0.add(const Duration(minutes: 15)),
    );

Photo photo(String id, {PhotoStatus status = PhotoStatus.uploaded}) => Photo(
      id: id,
      dateId: 'd1',
      status: status,
      isRepresentative: false,
      createdAt: t0,
    );

UploadTarget uploadTarget({DateTime? expiresAt}) => UploadTarget(
      url: 'https://storage.test/upload',
      method: 'PUT',
      headers: const {'Content-Type': 'image/jpeg'},
      expiresAt: expiresAt ?? t0.add(const Duration(minutes: 15)),
    );
