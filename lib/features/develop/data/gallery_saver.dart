import 'package:gal/gal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gallery_saver.g.dart';

/// 사진첩 접근이 거부됨.
class GalleryAccessDenied implements Exception {
  const GalleryAccessDenied();
}

/// OS 사진첩의 '포담' 앨범에 저장한다.
abstract interface class GallerySaver {
  /// 권한이 없으면 요청한다. 거부되면 false.
  Future<bool> ensureAccess();

  /// 실패하면 예외. 권한 문제면 [GalleryAccessDenied].
  Future<void> saveImage(String path);
}

class GalGallerySaver implements GallerySaver {
  static const album = '포담';

  @override
  Future<bool> ensureAccess() async {
    if (await Gal.hasAccess(toAlbum: true)) return true;
    return Gal.requestAccess(toAlbum: true);
  }

  @override
  Future<void> saveImage(String path) async {
    try {
      await Gal.putImage(path, album: album);
    } on GalException catch (e) {
      if (e.type == GalExceptionType.accessDenied) {
        throw const GalleryAccessDenied();
      }
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
GallerySaver gallerySaver(Ref ref) => GalGallerySaver();
