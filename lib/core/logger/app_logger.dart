import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/env.dart';

part 'app_logger.g.dart';

@Riverpod(keepAlive: true)
Logger appLogger(Ref ref) {
  return Logger(
    level: Env.isProd ? Level.warning : Level.debug,
    printer: PrettyPrinter(methodCount: 0),
  );
}
