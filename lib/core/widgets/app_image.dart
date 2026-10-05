import 'dart:io';

import 'package:flutter/material.dart';

/// 로컬 파일 우선, 없으면 URL(`http(s)`, `file://`, `asset:`)로 이미지를 그린다.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    this.url,
    this.localPath,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final String? localPath;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    if (path != null && File(path).existsSync()) {
      return Image.file(File(path), fit: fit, errorBuilder: _error);
    }
    final source = url;
    if (source == null) return _placeholder(context);
    if (source.startsWith('asset:')) {
      return Image.asset(source.substring(6), fit: fit, errorBuilder: _error);
    }
    if (source.startsWith('file://')) {
      return Image.file(
        File(Uri.parse(source).toFilePath()),
        fit: fit,
        errorBuilder: _error,
      );
    }
    return Image.network(
      source,
      fit: fit,
      errorBuilder: _error,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      );

  Widget _error(BuildContext context, Object error, StackTrace? stack) =>
      ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      );
}
