import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/network/api_error.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  runApp(
    ProviderScope(
      // 네트워크 오류만 재시도한다. 정책 오류(code)는 재시도해도 같다.
      retry: (count, error) =>
          error is ApiException && error.code == ApiErrorCode.network && count < 3
              ? Duration(seconds: 1 << count)
              : null,
      child: const App(),
    ),
  );
}
