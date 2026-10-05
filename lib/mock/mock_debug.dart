part of 'mock_backend.dart';

/// 개발용 "상대 행동 시뮬레이트". 현재 로그인한 사용자의 상대로 동작한다.
extension MockDebugActions on MockBackend {
  int _simCount() => _users.values.where((u) => u.devId.startsWith('sim-')).length;

  /// 가상의 상대를 만들어 바로 연결한다.
  void debugConnectPartner() {
    final me = _me;
    if (_coupleOf(me.id) != null) _fail(ApiErrorCode.coupleAlreadyConnected);
    final partner = _MUser(
      id: _uuid.v4(),
      devId: 'sim-${_simCount() + 1}',
      nickname: '다미',
    );
    _users[partner.id] = partner;
    final invite = _createInviteFor(partner.id);
    _joinCoupleAs(me.id, invite.code);
  }

  /// 가상의 상대가 만든 초대 코드. 사용자가 직접 입력해 볼 수 있다.
  String debugPartnerInviteCode() {
    final partner = _MUser(
      id: _uuid.v4(),
      devId: 'sim-${_simCount() + 1}',
      nickname: '다미',
    );
    _users[partner.id] = partner;
    return _createInviteFor(partner.id).code;
  }

  /// 가상의 상대가 내 최신 초대 코드를 입력한다.
  void debugPartnerAcceptMyInvite() {
    final me = _me;
    final invite = _invites
        .where((i) => i.ownerId == me.id && !i.used && !i.revoked)
        .lastOrNull;
    if (invite == null) _fail(ApiErrorCode.inviteInvalid);
    final partner = _MUser(
      id: _uuid.v4(),
      devId: 'sim-${_simCount() + 1}',
      nickname: '다미',
    );
    _users[partner.id] = partner;
    _joinCoupleAs(partner.id, invite.code);
  }

  String get _partnerId => _requireCouple(_me.id).partnerOf(_me.id);

  void debugPartnerStartDate() => _startDateAs(_partnerId);

  void debugPartnerJoin() {
    final date = _currentDateOf(_requireCouple(_me.id).id);
    if (date == null) _fail(ApiErrorCode.notFound);
    _joinDateAs(date.id, _partnerId);
  }

  /// 상대가 주제를 확인하고 한 장 찍어 제출한다.
  void debugPartnerSubmit() {
    final date = _currentDateOf(_requireCouple(_me.id).id);
    if (date == null) _fail(ApiErrorCode.notFound);
    final partnerId = _partnerId;
    _joinDateAs(date.id, partnerId);
    final photo = _MPhoto(
      id: _uuid.v4(),
      dateId: date.id,
      userId: partnerId,
      createdAt: _now,
    )
      ..status = PhotoStatus.uploaded
      ..uploadedAt = _now
      ..objectUrl = MockBackend.partnerPhotoUrl;
    _photos[photo.id] = photo;
    date.participants[partnerId]!.shotCount += 1;
    _submitAs(date.id, partnerId, photoId: photo.id, caption: '다미가 찍은 한 장');
  }

  /// 진행 중 데이트의 마감을 지금으로 당긴다(72시간 만료 시뮬레이트).
  void debugExpireDate() {
    final date = _currentDateOf(_requireCouple(_me.id).id);
    if (date == null) _fail(ApiErrorCode.notFound);
    date.deadlineAt = _now;
    _sweep();
  }

  void debugGrantFilm([int shots = MockBackend.rollSize]) {
    _me.filmBalance += shots;
  }
}
