import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock.g.dart';

/// 현재 시각. 테스트에서 고정한다.
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;
