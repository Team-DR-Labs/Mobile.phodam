import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'models/queued_photo.dart';

part 'upload_queue_store.g.dart';

/// 앱 문서 디렉터리의 업로드 큐(사진 파일 + 목록 JSON).
class UploadQueueStore {
  UploadQueueStore(this._directory);

  final Future<Directory> Function() _directory;

  static const _indexFile = 'queue.json';

  Future<Directory> _dir() async =>
      (await _directory()).create(recursive: true);

  Future<List<QueuedPhoto>> load() async {
    final file = File(p.join((await _dir()).path, _indexFile));
    if (!file.existsSync()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      return [
        for (final item in decoded)
          QueuedPhoto.fromJson(item as Map<String, dynamic>),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> save(List<QueuedPhoto> items) async {
    final dir = await _dir();
    final temp = File(p.join(dir.path, '$_indexFile.tmp'));
    await temp.writeAsString(jsonEncode([for (final i in items) i.toJson()]));
    await temp.rename(p.join(dir.path, _indexFile));
  }

  Future<String> writeImage(String photoId, Uint8List bytes) async {
    final file = File(p.join((await _dir()).path, '$photoId.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> deleteImage(String path) async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }
}

@Riverpod(keepAlive: true)
UploadQueueStore uploadQueueStore(Ref ref) => UploadQueueStore(() async {
      final docs = await getApplicationDocumentsDirectory();
      return Directory(p.join(docs.path, 'upload_queue'));
    });
