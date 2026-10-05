import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../core/network/api_error.dart';
import '../features/auth/data/models/auth_models.dart';
import '../features/camera/data/models/photo_models.dart';
import '../features/couple/data/models/couple_models.dart';
import '../features/date/data/models/date_models.dart';
import '../features/diary/data/models/diary_models.dart';
import '../features/me/data/models/me.dart';

part 'mock_backend.g.dart';
part 'mock_records.dart';
part 'mock_photos.dart';
part 'mock_debug.dart';

/// mvp-policy 를 흉내 내는 인메모리 가짜 서버.
///
/// 앱을 껐다 켜면 상태가 사라진다. 로그아웃 후 다른 dev_id 로 로그인하면
/// 같은 상태를 공유하므로 한 기기에서 두 사람을 번갈아 시뮬레이트할 수 있다.
class MockBackend {
  MockBackend({
    DateTime Function()? clock,
    Future<Directory> Function()? storageDir,
    Random? random,
  })  : _clock = clock ?? DateTime.now,
        _storageDir = storageDir ?? _defaultStorageDir,
        _random = random ?? Random();

  static const rollSize = 24;
  static const dateDuration = Duration(hours: 72);
  static const receiveDuration = Duration(days: 7);
  static const urlTtl = Duration(minutes: 15);
  static const captionMaxLength = 200;
  static const assetScheme = 'asset:';
  static const partnerPhotoUrl = '${assetScheme}assets/images/dami.png';
  static const _inviteAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  final DateTime Function() _clock;
  final Future<Directory> Function() _storageDir;
  final Random _random;
  final _uuid = const Uuid();

  final _users = <String, _MUser>{};
  final _invites = <_MInvite>[];
  final _couples = <String, _MCouple>{};
  final _dates = <String, _MDate>{};
  final _photos = <String, _MPhoto>{};
  final _themes = [
    for (final (title, topics) in _seedThemes)
      (
        DateTheme(id: const Uuid().v4(), title: title),
        [for (final t in topics) Topic(id: const Uuid().v4(), title: t)],
      ),
  ];
  String? _currentUserId;

  static Future<Directory> _defaultStorageDir() async {
    final base = await getTemporaryDirectory();
    return Directory(p.join(base.path, 'mock_storage')).create(recursive: true);
  }

  DateTime get _now => _clock().toUtc();

  Never _fail(ApiErrorCode code) => throw ApiException(code);

  _MUser get _me {
    final id = _currentUserId;
    if (id == null || !_users.containsKey(id)) _fail(ApiErrorCode.unauthorized);
    return _users[id]!;
  }

  _MCouple? _coupleOf(String userId) {
    for (final couple in _couples.values) {
      if (couple.userA == userId || couple.userB == userId) return couple;
    }
    return null;
  }

  _MCouple _requireCouple(String userId) =>
      _coupleOf(userId) ?? _fail(ApiErrorCode.coupleRequired);

  // ---------- auth / me ----------

  AuthResponse login(String devId, {String? nickname}) {
    final existing = _users.values.where((u) => u.devId == devId).firstOrNull;
    final user = existing ??
        _MUser(
          id: _uuid.v4(),
          devId: devId,
          nickname: (nickname?.trim().isNotEmpty ?? false)
              ? nickname!.trim()
              : '포담 사용자',
        );
    _users[user.id] = user;
    _currentUserId = user.id;
    final now = _now;
    return AuthResponse(
      accessToken: 'mock-access-${user.id}',
      accessTokenExpiresAt: now.add(const Duration(hours: 1)),
      refreshToken: 'mock-refresh-${user.id}',
      refreshTokenExpiresAt: now.add(const Duration(days: 30)),
      isNewUser: existing == null,
      user: user.toUser(),
    );
  }

  Me me() {
    _sweep();
    final user = _me;
    final couple = _coupleOf(user.id);
    final current = couple == null ? null : _currentDateOf(couple.id);
    return Me(
      user: user.toUser(),
      filmBalance: user.filmBalance,
      couple: couple == null ? null : _coupleView(couple, user.id),
      currentDate: current == null ? null : _dateView(current, user.id),
    );
  }

  Me updateNickname(String nickname) {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty || trimmed.length > 20) {
      _fail(ApiErrorCode.validationFailed);
    }
    _me.nickname = trimmed;
    return me();
  }

  // ---------- couple ----------

  Couple _coupleView(_MCouple couple, String viewerId) => Couple(
        id: couple.id,
        partner: _users[couple.partnerOf(viewerId)]!.toUser(),
        connectedAt: couple.connectedAt,
      );

  Invite createInvite() => _createInviteFor(_me.id);

  Invite _createInviteFor(String userId) {
    if (_coupleOf(userId) != null) _fail(ApiErrorCode.coupleAlreadyConnected);
    for (final invite in _invites.where((i) => i.ownerId == userId)) {
      invite.revoked = true;
    }
    final code = List.generate(
      8,
      (_) => _inviteAlphabet[_random.nextInt(_inviteAlphabet.length)],
    ).join();
    final invite = _MInvite(
      code: code,
      ownerId: userId,
      expiresAt: _now.add(const Duration(hours: 24)),
    );
    _invites.add(invite);
    return Invite(code: invite.code, expiresAt: invite.expiresAt);
  }

  Couple joinCouple(String code) => _joinCoupleAs(_me.id, code);

  Couple _joinCoupleAs(String userId, String code) {
    final invite = _invites
        .where((i) => i.code == code.trim().toUpperCase())
        .firstOrNull;
    if (invite == null ||
        invite.used ||
        invite.revoked ||
        !_now.isBefore(invite.expiresAt) ||
        invite.ownerId == userId) {
      _fail(ApiErrorCode.inviteInvalid);
    }
    if (_coupleOf(userId) != null || _coupleOf(invite.ownerId) != null) {
      _fail(ApiErrorCode.coupleAlreadyConnected);
    }
    invite.used = true;
    final couple = _MCouple(
      id: _uuid.v4(),
      userA: invite.ownerId,
      userB: userId,
      connectedAt: _now,
    );
    _couples[couple.id] = couple;
    return _coupleView(couple, userId);
  }

  // ---------- date ----------

  _MDate? _currentDateOf(String coupleId) => _dates.values
      .where((d) => d.coupleId == coupleId && d.status == DateStatus.inProgress)
      .firstOrNull;

  DateView _dateView(_MDate date, String viewerId) {
    final mine = date.participants[viewerId]!;
    final partnerId =
        date.participants.keys.firstWhere((id) => id != viewerId);
    final partner = date.participants[partnerId]!;
    return DateView(
      id: date.id,
      status: date.status,
      theme: date.theme,
      startedByMe: date.startedBy == viewerId,
      startedAt: date.startedAt,
      deadlineAt: date.deadlineAt,
      revealedAt: date.revealedAt,
      me: MyParticipation(
        status: mine.status,
        topic: mine.status == ParticipantStatus.assigned ? null : mine.topic,
        joinedAt: mine.joinedAt,
        submittedAt: mine.submittedAt,
        receiveDeadlineAt: mine.receiveDeadlineAt,
        shotCount: mine.shotCount,
      ),
      partner: PartnerParticipation(
        user: _users[partnerId]!.toUser(),
        status: partner.status,
        // 상대 주제는 공동 공개 전에는 절대 내보내지 않는다.
        topic: date.status == DateStatus.revealed ? partner.topic : null,
      ),
    );
  }

  DateView startDate() => _dateView(_startDateAs(_me.id), _me.id);

  _MDate _startDateAs(String userId) {
    _sweep();
    final couple = _requireCouple(userId);
    if (_currentDateOf(couple.id) != null) {
      _fail(ApiErrorCode.dateAlreadyInProgress);
    }
    final (theme, topics) = _pickTheme(couple.id);
    final picked = [...topics]..shuffle(_random);
    final now = _now;
    final partnerId = couple.partnerOf(userId);
    final date = _MDate(
      id: _uuid.v4(),
      coupleId: couple.id,
      theme: theme,
      startedBy: userId,
      startedAt: now,
      participants: {
        userId: _MParticipant(
          userId: userId,
          topic: picked[0],
          status: ParticipantStatus.joined,
        )..joinedAt = now,
        partnerId: _MParticipant(
          userId: partnerId,
          topic: picked[1],
          status: ParticipantStatus.assigned,
        ),
      },
    );
    _dates[date.id] = date;
    return date;
  }

  (DateTheme, List<Topic>) _pickTheme(String coupleId) {
    final history = _dates.values.where((d) => d.coupleId == coupleId).toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final used = history.map((d) => d.theme.id).toSet();
    var pool = _themes.where((t) => !used.contains(t.$1.id)).toList();
    if (pool.isEmpty) {
      final last = history.last.theme.id;
      pool = _themes.where((t) => t.$1.id != last).toList();
    }
    return pool[_random.nextInt(pool.length)];
  }

  _MDate _participantDate(String dateId, String userId) {
    _sweep();
    final date = _dates[dateId];
    if (date == null || !date.participants.containsKey(userId)) {
      _fail(ApiErrorCode.notFound);
    }
    return date;
  }

  DateView getDate(String dateId) =>
      _dateView(_participantDate(dateId, _me.id), _me.id);

  DateView joinDate(String dateId) {
    final userId = _me.id;
    _joinDateAs(dateId, userId);
    return _dateView(_dates[dateId]!, userId);
  }

  void _joinDateAs(String dateId, String userId) {
    final date = _participantDate(dateId, userId);
    final mine = date.participants[userId]!;
    if (mine.status != ParticipantStatus.assigned) return;
    if (date.status != DateStatus.inProgress) _fail(ApiErrorCode.dateNotActive);
    mine
      ..status = ParticipantStatus.joined
      ..joinedAt = _now;
  }

  /// 촬영·제출 공통 조건(정책 §6, §7).
  _MParticipant _requireShootable(_MDate date, String userId) {
    if (date.status != DateStatus.inProgress ||
        !_now.isBefore(date.deadlineAt)) {
      _fail(ApiErrorCode.dateNotActive);
    }
    final mine = date.participants[userId]!;
    if (mine.status == ParticipantStatus.submitted) {
      _fail(ApiErrorCode.alreadySubmitted);
    }
    if (mine.status != ParticipantStatus.joined) {
      _fail(ApiErrorCode.dateNotJoined);
    }
    return mine;
  }

  DateView submit(String dateId, {required String photoId, String? caption}) {
    final userId = _me.id;
    _submitAs(dateId, userId, photoId: photoId, caption: caption);
    return _dateView(_dates[dateId]!, userId);
  }

  void _submitAs(
    String dateId,
    String userId, {
    required String photoId,
    String? caption,
  }) {
    final date = _participantDate(dateId, userId);
    final mine = _requireShootable(date, userId);
    final trimmed = caption?.trim();
    if (trimmed != null && trimmed.runes.length > captionMaxLength) {
      _fail(ApiErrorCode.validationFailed);
    }
    final photo = _photos[photoId];
    if (photo == null || photo.userId != userId || photo.dateId != dateId) {
      _fail(ApiErrorCode.notFound);
    }
    if (photo.status != PhotoStatus.uploaded) {
      _fail(ApiErrorCode.photoNotUploaded);
    }
    final now = _now;
    photo
      ..status = PhotoStatus.archived
      ..isRepresentative = true;
    mine
      ..representativePhotoId = photo.id
      ..caption = (trimmed?.isEmpty ?? true) ? null : trimmed
      ..status = ParticipantStatus.submitted
      ..submittedAt = now
      ..receiveDeadlineAt = now.add(receiveDuration);
    for (final reserved in _photosOf(dateId, userId)
        .where((ph) => ph.status == PhotoStatus.reserved)) {
      reserved.status = PhotoStatus.deleted;
    }
    final allSubmitted = date.participants.values
        .every((pt) => pt.status == ParticipantStatus.submitted);
    if (allSubmitted) {
      date
        ..status = DateStatus.revealed
        ..revealedAt = now;
    }
  }

  Iterable<_MPhoto> _photosOf(String dateId, String userId) => _photos.values
      .where((ph) => ph.dateId == dateId && ph.userId == userId);

  /// 요청 시점 만료 판정 + 워커 동작(정책 §2, §11).
  void _sweep() {
    final now = _now;
    for (final date in _dates.values) {
      if (date.status == DateStatus.inProgress &&
          !now.isBefore(date.deadlineAt)) {
        date.status = DateStatus.expired;
        for (final pt in date.participants.values
            .where((pt) => pt.status != ParticipantStatus.submitted)) {
          for (final ph in _photosOf(date.id, pt.userId).where((ph) =>
              ph.status == PhotoStatus.reserved ||
              ph.status == PhotoStatus.uploaded)) {
            ph.status = PhotoStatus.deleted;
          }
        }
      }
      for (final pt in date.participants.values) {
        final deadline = pt.receiveDeadlineAt;
        if (deadline == null || now.isBefore(deadline)) continue;
        for (final ph in _photosOf(date.id, pt.userId)
            .where((ph) => ph.status == PhotoStatus.uploaded)) {
          ph.status = PhotoStatus.deleted;
        }
      }
    }
  }
}

@Riverpod(keepAlive: true)
MockBackend mockBackend(Ref ref) => MockBackend();
