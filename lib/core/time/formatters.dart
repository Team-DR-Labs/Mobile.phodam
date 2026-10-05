import 'package:intl/intl.dart';

/// 화면 표시용 날짜 문구. 시각은 기기 로컬 시간으로 보여준다.
abstract final class Formats {
  static String dateTime(DateTime value) =>
      DateFormat('M월 d일 HH:mm', 'ko').format(value.toLocal());

  /// `YYYY-MM-DD` → `2026년 10월 5일 (일)`.
  static String localDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('yyyy년 M월 d일 (E)', 'ko').format(parsed);
  }
}
