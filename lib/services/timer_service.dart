import 'dart:async';
import 'package:flutter/foundation.dart';

class TimerService extends ChangeNotifier {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  Timer? _timer;
  DateTime? _startTime;
  int _elapsedSeconds = 0;
  bool _isRunning = false;

  bool get isRunning => _isRunning;
  int get elapsedSeconds => _elapsedSeconds;
  DateTime? get startTime => _startTime;

  String get formattedTime {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int get elapsedMinutes => _elapsedSeconds ~/ 60;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    notifyListeners();
  }

  void reset() {
    stop();
    _elapsedSeconds = 0;
    _startTime = null;
    notifyListeners();
  }

  /// Start from a specific time (e.g., the start time of the activity)
  void startFrom(DateTime time) {
    reset();
    _startTime = time;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds = DateTime.now().difference(_startTime!).inSeconds;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
