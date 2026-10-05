import 'package:flutter_test/flutter_test.dart';
import 'package:phodam/core/config/env.dart';

void main() {
  test('define 없이 만든 빌드는 운영으로 본다', () {
    expect(Env.name, 'prod');
    expect(Env.isProd, isTrue);
    expect(Env.devToolsEnabled, isFalse);
  });

  test('개발 도구는 dev·mock 을 명시한 비릴리스 빌드에서만 허용', () {
    bool allowed(String name, {bool release = false}) =>
        Env.devToolsAllowed(name: name, releaseMode: release);

    expect(allowed('dev'), isTrue);
    expect(allowed('mock'), isTrue);
    expect(allowed('prod'), isFalse);
    expect(allowed('staging'), isFalse);
    expect(allowed('dev', release: true), isFalse);
    expect(allowed('mock', release: true), isFalse);
  });
}
