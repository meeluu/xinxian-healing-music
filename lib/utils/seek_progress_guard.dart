import 'dart:math' as math;

/// Shared seek progress rules for the local player seek guard.
///
/// Kept separate from the widget so the important timing and tolerance rules can
/// be tested without mocking just_audio.
class SeekProgressGuard {
  SeekProgressGuard._();

  /// Long enough for Flutter Web / HTML audio seek to settle on first load.
  static const Duration pendingSeekFallbackDelay = Duration(seconds: 3);

  /// A short post-seek check gives positionStream one more tick before fallback.
  static const Duration postSeekCheckDelay = Duration(milliseconds: 180);

  static Duration toleranceFor(Duration total) {
    if (total.inMilliseconds <= 0) return const Duration(milliseconds: 300);
    final toleranceMs = math.max(total.inMilliseconds * 0.02, 300).round();
    return Duration(milliseconds: toleranceMs);
  }

  static Duration targetFromSliderValue({
    required double value,
    required Duration total,
  }) {
    final clamped = value.clamp(0.0, 1.0);
    final targetMs = (clamped * total.inMilliseconds).round().clamp(
      0,
      total.inMilliseconds,
    );
    return Duration(milliseconds: targetMs);
  }

  static bool positionReachedTarget({
    required Duration position,
    required Duration target,
    required Duration total,
  }) {
    if (total.inMilliseconds <= 0) return false;
    final diffMs = (position.inMilliseconds - target.inMilliseconds).abs();
    return diffMs <= toleranceFor(total).inMilliseconds;
  }
}
