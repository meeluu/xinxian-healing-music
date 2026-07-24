import 'package:just_audio/just_audio.dart';

/// Readiness gate for user-initiated seek on the local assets player.
///
/// Flutter Web can expose a duration before the underlying HTML audio element is
/// actually ready to seek on a first uncached load. Keep the rule small and
/// testable so the widget only enables the slider once the source is loaded.
class AudioSeekReadiness {
  AudioSeekReadiness._();

  static bool canSeek({
    required Duration? duration,
    required ProcessingState processingState,
  }) {
    final hasDuration = duration != null && duration > Duration.zero;
    final sourceReady =
        processingState == ProcessingState.ready ||
        processingState == ProcessingState.completed;
    return hasDuration && sourceReady;
  }
}
