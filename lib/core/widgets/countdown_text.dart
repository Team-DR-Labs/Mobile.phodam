import 'dart:async';

import 'package:flutter/material.dart';

/// 남은 시간을 사람이 읽는 문구로. 지났으면 '마감됐어요'.
String formatRemaining(Duration remaining) {
  if (remaining <= Duration.zero) return '마감됐어요';
  final days = remaining.inDays;
  final hours = remaining.inHours % 24;
  final minutes = remaining.inMinutes % 60;
  final seconds = remaining.inSeconds % 60;
  if (days > 0) return '$days일 $hours시간 남음';
  if (hours > 0) return '$hours시간 $minutes분 남음';
  return '$minutes분 $seconds초 남음';
}

/// [deadline] 까지 1초마다 갱신되는 카운트다운.
class CountdownText extends StatefulWidget {
  const CountdownText({
    super.key,
    required this.deadline,
    this.style,
    this.now = DateTime.now,
  });

  final DateTime deadline;
  final TextStyle? style;
  final DateTime Function() now;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.deadline.difference(widget.now());
    return Text(formatRemaining(remaining), style: widget.style);
  }
}
