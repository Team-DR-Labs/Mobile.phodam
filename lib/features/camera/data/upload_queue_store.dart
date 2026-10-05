import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'models/queued_photo.dart';

part 'upload_queue_store.g.dart';

/// 앱 문서 디렉터리의 업로드 큐. 사진 한 장마다 `<id>.jpg` 와 `<id>.json` 을 둔다.
///
/// - 항목별 파일이라 한 파일이 깨져도 나머지는 남는다. 깨진 파일은 `.corrupt` 로 보존한다.
/// - 쓰기는 직렬화하고, 고유한 임시 파일에 쓴 뒤 rename 해 원자적으로 바꾼다.
class UploadQueueStore {
  UploadQueueStore(this._directory);

  final Future<Directory> Function() _directory;
  Future<void> _tail = Future.value();
  int _tmpSeq = 0;

  static const _entrySuffix = '.json';
  static const corruptSuffix = '.corrupt';

  Future<Directory> _dir() async =>
      (await _directory()).create(recursive: true);

  /// 쓰기 작업을 한 줄로 세운다. 앞 작업이 실패해도 다음 작업은 진행한다.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<List<QueuedPhoto>> load() => _serial(() async {
        final dir = await _dir();
        final items = <QueuedPhoto>[];
        for (final file in dir.listSync().whereType<File>()) {
          if (!file.path.endsWith(_entrySuffix)) continue;
          try {
            final json = jsonDecode(await file.readAsString());
            items.add(QueuedPhoto.fromJson(json as Map<String, dynamic>));
          } catch (_) {
            // 사진 파일은 그대로 두고 깨진 항목만 보존해 둔다.
            await file.rename('${file.path}$corruptSuffix');
          }
        }
        return items..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });

  Future<void> put(QueuedPhoto item) => _serial(() async {
        final dir = await _dir();
        final target = p.join(dir.path, '${item.photoId}$_entrySuffix');
        final temp = File('$target.${DateTime.now().microsecondsSinceEpoch}'
            '-${_tmpSeq++}.tmp');
        await temp.writeAsString(jsonEncode(item.toJson()), flush: true);
        await temp.rename(target);
      });

  /// 항목과 사진 파일을 함께 지운다.
  Future<void> delete(QueuedPhoto item) => _serial(() async {
        final dir = await _dir();
        for (final path in [
          p.join(dir.path, '${item.photoId}$_entrySuffix'),
          item.filePath,
        ]) {
          final file = File(path);
          if (file.existsSync()) await file.delete();
        }
      });

  Future<String> writeImage(String photoId, Uint8List bytes) async {
    final file = File(p.join((await _dir()).path, '$photoId.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

@Riverpod(keepAlive: true)
UploadQueueStore uploadQueueStore(Ref ref) => UploadQueueStore(() async {
      final docs = await getApplicationDocumentsDirectory();
      return Directory(p.join(docs.path, 'upload_queue'));
    });
