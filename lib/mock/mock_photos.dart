part of 'mock_backend.dart';

/// 촬영·업로드·수령·일기 (정책 §6, §8, §9, §10).
extension MockPhotoEndpoints on MockBackend {
  ShotReservation reserveShot(String dateId) {
    final user = _me;
    final date = _participantDate(dateId, user.id);
    final mine = _requireShootable(date, user.id);
    if (user.filmBalance <= 0) _fail(ApiErrorCode.filmExhausted);
    user.filmBalance -= 1;
    mine.shotCount += 1;
    final photo = _MPhoto(
      id: _uuid.v4(),
      dateId: dateId,
      userId: user.id,
      createdAt: _now,
    );
    _photos[photo.id] = photo;
    return ShotReservation(
      photo: photo.toPhoto(),
      upload: _uploadTarget(photo.id),
      filmBalance: user.filmBalance,
    );
  }

  UploadTarget _uploadTarget(String photoId) => UploadTarget(
        url: 'mock-upload://$photoId',
        method: 'PUT',
        headers: const {'Content-Type': 'image/jpeg'},
        expiresAt: _now.add(MockBackend.urlTtl),
      );

  _MPhoto _myPhoto(String photoId) {
    _sweep();
    final photo = _photos[photoId];
    if (photo == null || photo.userId != _me.id) _fail(ApiErrorCode.notFound);
    return photo;
  }

  UploadTarget reissueUploadUrl(String photoId) {
    final photo = _myPhoto(photoId);
    _requireShootable(_dates[photo.dateId]!, photo.userId);
    if (photo.status != PhotoStatus.reserved) _fail(ApiErrorCode.notFound);
    return _uploadTarget(photo.id);
  }

  /// presigned PUT 대상. 파일로 저장한다.
  Future<void> storeObject(String photoId, Uint8List bytes) async {
    final photo = _photos[photoId];
    if (photo == null || photo.status != PhotoStatus.reserved) {
      _fail(ApiErrorCode.forbidden);
    }
    final dir = await _storageDir();
    final file = File(p.join(dir.path, '$photoId.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    photo.objectUrl = file.uri.toString();
  }

  Photo complete(String photoId) {
    final photo = _myPhoto(photoId);
    if (photo.status == PhotoStatus.uploaded) return photo.toPhoto();
    if (photo.status != PhotoStatus.reserved) _fail(ApiErrorCode.notFound);
    if (photo.objectUrl == null) _fail(ApiErrorCode.photoNotUploaded);
    photo
      ..status = PhotoStatus.uploaded
      ..uploadedAt = _now;
    return photo.toPhoto();
  }

  List<PhotoWithUrl> myPhotos(String dateId) {
    final user = _me;
    _participantDate(dateId, user.id);
    final expires = _now.add(MockBackend.urlTtl);
    return _photosOf(dateId, user.id)
        .where((ph) =>
            ph.status == PhotoStatus.uploaded ||
            ph.status == PhotoStatus.archived)
        .map((ph) => ph.withUrl(expires))
        .toList();
  }

  _MParticipant _requireReceivable(String dateId, String userId) {
    final date = _participantDate(dateId, userId);
    final mine = date.participants[userId]!;
    final deadline = mine.receiveDeadlineAt;
    if (mine.status != ParticipantStatus.submitted ||
        deadline == null ||
        !_now.isBefore(deadline)) {
      _fail(ApiErrorCode.receiveNotAvailable);
    }
    return mine;
  }

  Receivable receivable(String dateId) {
    final user = _me;
    final mine = _requireReceivable(dateId, user.id);
    final expires = _now.add(MockBackend.urlTtl);
    final items = _photosOf(dateId, user.id)
        .where((ph) =>
            ph.status == PhotoStatus.uploaded ||
            (ph.isRepresentative && ph.status == PhotoStatus.archived))
        .map((ph) => ph.withUrl(expires))
        .toList();
    return Receivable(receiveDeadlineAt: mine.receiveDeadlineAt!, items: items);
  }

  Photo ackReceived(String photoId) {
    final photo = _myPhoto(photoId);
    _requireReceivable(photo.dateId, photo.userId);
    if (photo.isRepresentative) {
      photo.receivedAt ??= _now;
      return photo.toPhoto();
    }
    if (photo.status == PhotoStatus.received) return photo.toPhoto();
    if (photo.status != PhotoStatus.uploaded) _fail(ApiErrorCode.notFound);
    photo
      ..status = PhotoStatus.received
      ..receivedAt = _now
      ..objectUrl = null;
    return photo.toPhoto();
  }

  // ---------- diary ----------

  static String _seoulDate(DateTime utc) {
    final local = utc.toUtc().add(const Duration(hours: 9));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  DiaryVisibility _visibility(_MDate date) => switch (date.status) {
        DateStatus.revealed => DiaryVisibility.shared,
        DateStatus.inProgress => DiaryVisibility.waiting,
        DateStatus.expired => DiaryVisibility.private,
      };

  List<_MDate> _myDiaryDates(String userId) {
    _sweep();
    return _dates.values
        .where((d) =>
            d.participants[userId]?.status == ParticipantStatus.submitted)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  DiaryList diaries({String? cursor, int limit = 20}) {
    final user = _me;
    _requireCouple(user.id);
    final all = _myDiaryDates(user.id);
    final start = int.tryParse(cursor ?? '') ?? 0;
    final end = min(start + limit.clamp(1, 50), all.length);
    final expires = _now.add(MockBackend.urlTtl);
    final items = [
      for (final date in all.sublist(min(start, all.length), end))
        DiaryListItem(
          dateId: date.id,
          localDate: _seoulDate(date.startedAt),
          theme: date.theme,
          visibility: _visibility(date),
          startedAt: date.startedAt,
          thumbnailUrl:
              _photos[date.participants[user.id]!.representativePhotoId]!
                  .objectUrl!,
          thumbnailUrlExpiresAt: expires,
        ),
    ];
    return DiaryList(
      items: items,
      nextCursor: end < all.length ? '$end' : null,
    );
  }

  DiaryDetail diary(String dateId) {
    final user = _me;
    final date = _dates[dateId];
    final mine = date?.participants[user.id];
    if (date == null ||
        mine == null ||
        mine.status != ParticipantStatus.submitted) {
      _fail(ApiErrorCode.notFound);
    }
    final expires = _now.add(MockBackend.urlTtl);
    DiaryEntry entry(_MParticipant pt) => DiaryEntry(
          author: _users[pt.userId]!.toUser(),
          isMe: pt.userId == user.id,
          topic: pt.topic,
          caption: pt.caption,
          photoUrl: _photos[pt.representativePhotoId]!.objectUrl!,
          photoUrlExpiresAt: expires,
          submittedAt: pt.submittedAt!,
        );
    final partner =
        date.participants.values.firstWhere((pt) => pt.userId != user.id);
    return DiaryDetail(
      dateId: date.id,
      localDate: _seoulDate(date.startedAt),
      theme: date.theme,
      visibility: _visibility(date),
      startedAt: date.startedAt,
      entries: [
        entry(mine),
        if (date.status == DateStatus.revealed) entry(partner),
      ],
    );
  }
}
