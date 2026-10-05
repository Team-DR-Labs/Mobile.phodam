import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/dio_provider.dart';
import '../../../mock/mock_backend.dart';
import 'models/photo_models.dart';

part 'photo_transfer.g.dart';

/// presigned URL 로 파일을 올리고 내려받는다.
abstract interface class PhotoTransfer {
  Future<void> upload(UploadTarget target, File file);

  Future<File> download(String url, String destinationPath);
}

class DioPhotoTransfer implements PhotoTransfer {
  DioPhotoTransfer(this._dio);

  /// 인증 인터셉터가 없는 Dio.
  final Dio _dio;

  @override
  Future<void> upload(UploadTarget target, File file) => guardApi(() async {
        final length = await file.length();
        await _dio.request<void>(
          target.url,
          data: file.openRead(),
          options: Options(
            method: target.method,
            headers: {
              ...target.headers,
              Headers.contentLengthHeader: length,
            },
          ),
        );
      });

  @override
  Future<File> download(String url, String destinationPath) =>
      guardApi(() async {
        await _dio.download(url, destinationPath);
        return File(destinationPath);
      });
}

/// 가짜 서버용 전송. `mock-upload://<photoId>` 와 `file://`, `asset:` URL 을 처리한다.
class MockPhotoTransfer implements PhotoTransfer {
  MockPhotoTransfer(this._backend);

  final MockBackend _backend;

  @override
  Future<void> upload(UploadTarget target, File file) async {
    final photoId = Uri.parse(target.url).host;
    await _backend.storeObject(photoId, await file.readAsBytes());
  }

  @override
  Future<File> download(String url, String destinationPath) async {
    final destination = File(destinationPath);
    if (url.startsWith(MockBackend.assetScheme)) {
      final data =
          await rootBundle.load(url.substring(MockBackend.assetScheme.length));
      return destination.writeAsBytes(data.buffer.asUint8List());
    }
    return File(Uri.parse(url).toFilePath()).copy(destinationPath);
  }
}

@Riverpod(keepAlive: true)
PhotoTransfer photoTransfer(Ref ref) {
  if (Env.useMock) return MockPhotoTransfer(ref.watch(mockBackendProvider));
  return DioPhotoTransfer(ref.watch(transferDioProvider));
}
