import 'dart:async';
import 'package:flutter/foundation.dart';

class QuestionTimer extends ChangeNotifier {
  Timer? _timer;
  final ValueNotifier<int> timeRemaining = ValueNotifier<int>(10);
  final int maxTime;
  final VoidCallback onTimeUp;

  QuestionTimer({
    required this.onTimeUp,
    this.maxTime = 10,
  });

  void start() {
    _timer?.cancel();
    timeRemaining.value = maxTime;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeRemaining.value > 0) {
        timeRemaining.value--;
      } else {
        timer.cancel();
        onTimeUp();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    timeRemaining.dispose();
    super.dispose();
  }
} 