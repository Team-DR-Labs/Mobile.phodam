import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:phodam/features/camera/data/film_look.dart';

void main() {
  test('긴 변을 2048px 로 줄이고 JPEG 로 만든다', () {
    final source = img.Image(width: 3000, height: 1500)
      ..clear(img.ColorRgb8(120, 120, 120));
    final output = processFilmImage(img.encodePng(source));

    final decoded = img.decodeJpg(output)!;
    expect(decoded.width, 2048);
    expect(decoded.height, 1024);
  });

  test('작은 사진은 키우지 않고 따뜻한 색감을 입힌다', () {
    final source = img.Image(width: 64, height: 48)
      ..clear(img.ColorRgb8(128, 128, 128));
    final decoded = img.decodeJpg(processFilmImage(img.encodeJpg(source)))!;

    expect(decoded.width, 64);
    var red = 0.0, blue = 0.0;
    for (final p in decoded) {
      red += p.r;
      blue += p.b;
    }
    expect(red, greaterThan(blue));
  });

  test('미리보기 행렬은 ColorFilter.matrix 형식(20개)이다', () {
    expect(FilmLook.matrix, hasLength(20));
  });
}
