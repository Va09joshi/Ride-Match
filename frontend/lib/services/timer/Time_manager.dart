import 'dart:async';

class RideTimerManager {
  // Singleton
  RideTimerManager._privateConstructor();
  static final RideTimerManager instance = RideTimerManager._privateConstructor();

  final Map<String, int> _timers = {};
  Timer? _timer;

  // Get remaining time for a ride
  int getRemaining(String rideId) => _timers[rideId] ?? 0;

  // Initialize timer for a ride (default 10 min)
  void initTimer(String rideId, {int seconds = 100}) {
    _timers[rideId] ??= seconds;
    _startGlobalTimer();
  }

  // Decrement all timers every second
  void _startGlobalTimer() {
    if (_timer != null) return; // already running

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _timers.forEach((key, value) {
        if (value > 0) _timers[key] = value - 1;
      });
    });
  }

  // Get all timers (read-only)
  Map<String, int> get timers => Map.unmodifiable(_timers);

  // Dispose timer
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
