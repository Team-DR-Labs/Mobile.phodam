import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'film_look.g.dart';

/// MVP 의 유일한 필름 색감. 미리보기와 저장 이미지에 같은 행렬을 쓴다.
abstract final class FilmLook {
  /// [ColorFilter.matrix] 형식(4x5, 오프셋은 0~255).
  static const matrix = <double>[
    1.08, 0.06, 0.00, 0, 10, //
    0.02, 1.00, 0.02, 0, 4,
    0.00, 0.06, 0.84, 0, -4,
    0, 0, 0, 1, 0,
  ];

  /// 그레인 세기(픽셀값 ±).
  static const grain = 6.0;

  static const maxLongSide = 2048;
  static const jpegQuality = 85;
}

/// 촬영 원본에 필름 색감과 미세 그레인을 입히고 긴 변 2048px JPEG(q85)로 만든다.
///
/// 무거운 작업이므로 [Isolate.run] 으로 실행한다.
Uint8List processFilmImage(Uint8List input, {int seed = 1}) {
  final decoded = img.decodeImage(input);
  if (decoded == null) throw const FormatException('이미지를 읽을 수 없어요');
  var image = _resize(img.bakeOrientation(decoded));
  if (image.format != img.Format.uint8 || image.hasPalette) {
    image = image.convert(format: img.Format.uint8, numChannels: 3);
  }
  final m = FilmLook.matrix;
  final random = Random(seed);
  for (final pixel in image) {
    final r = pixel.r.toDouble();
    final g = pixel.g.toDouble();
    final b = pixel.b.toDouble();
    final noise = (random.nextDouble() * 2 - 1) * FilmLook.grain;
    pixel
      ..r = _clamp(m[0] * r + m[1] * g + m[2] * b + m[4] + noise)
      ..g = _clamp(m[5] * r + m[6] * g + m[7] * b + m[9] + noise)
      ..b = _clamp(m[10] * r + m[11] * g + m[12] * b + m[14] + noise);
  }
  return img.encodeJpg(image, quality: FilmLook.jpegQuality);
}

img.Image _resize(img.Image image) {
  if (max(image.width, image.height) <= FilmLook.maxLongSide) return image;
  return image.width >= image.height
      ? img.copyResize(image, width: FilmLook.maxLongSide)
      : img.copyResize(image, height: FilmLook.maxLongSide);
}

int _clamp(double value) => value.round().clamp(0, 255);

typedef FilmProcessor = Future<Uint8List> Function(Uint8List raw);

@Riverpod(keepAlive: true)
FilmProcessor filmProcessor(Ref ref) =>
    (raw) => Isolate.run(() => processFilmImage(raw, seed: raw.length));
