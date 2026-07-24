import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:xinxian_healing_music/utils/audio_seek_readiness.dart';

void main() {
  group('AudioSeekReadiness', () {
    test('does not allow seek before duration is known', () {
      expect(
        AudioSeekReadiness.canSeek(
          duration: null,
          processingState: ProcessingState.ready,
        ),
        isFalse,
      );
    });

    test('does not allow seek while source is idle/loading/buffering', () {
      for (final state in [
        ProcessingState.idle,
        ProcessingState.loading,
        ProcessingState.buffering,
      ]) {
        expect(
          AudioSeekReadiness.canSeek(
            duration: const Duration(minutes: 3),
            processingState: state,
          ),
          isFalse,
        );
      }
    });

    test('allows seek once source is ready with a positive duration', () {
      expect(
        AudioSeekReadiness.canSeek(
          duration: const Duration(minutes: 3),
          processingState: ProcessingState.ready,
        ),
        isTrue,
      );
    });

    test('allows completed audio to be manually seeked before replay', () {
      expect(
        AudioSeekReadiness.canSeek(
          duration: const Duration(minutes: 3),
          processingState: ProcessingState.completed,
        ),
        isTrue,
      );
    });
  });
}
