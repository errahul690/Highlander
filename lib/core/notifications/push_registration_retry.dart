import 'dart:async';

/// Bounded backoff for delayed APNs registration and temporary network failures.
/// The caller supplies the session guard so a retry cannot revive a logged-out
/// account or register a device for a replacement session.
class PushRegistrationRetry {
  static const delays = [2, 5, 10, 20, 30, 60];
  Timer? _timer;
  int _attempts = 0;

  bool schedule({
    required bool Function() isCurrent,
    required void Function() retry,
  }) {
    if (_timer != null || _attempts >= delays.length || !isCurrent()) {
      return false;
    }
    final seconds = delays[_attempts++];
    _timer = Timer(Duration(seconds: seconds), () {
      _timer = null;
      if (isCurrent()) retry();
    });
    return true;
  }

  void cancel({bool reset = true}) {
    _timer?.cancel();
    _timer = null;
    if (reset) _attempts = 0;
  }
}

Future<bool> waitForApnsToken({
  required Future<String?> Function() readToken,
  required bool Function() isCurrent,
  Future<void> Function(Duration)? delay,
}) async {
  for (var attempt = 0; attempt <= 10; attempt++) {
    if (!isCurrent()) return false;
    final token = await readToken();
    if (!isCurrent()) return false;
    if (token != null && token.isNotEmpty) return true;
    if (attempt < 10) {
      await (delay ?? Future<void>.delayed)(const Duration(milliseconds: 300));
    }
  }
  return false;
}
