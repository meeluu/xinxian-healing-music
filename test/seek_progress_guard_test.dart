import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/utils/seek_progress_guard.dart';

void main() {
  group('SeekProgressGuard', () {
    test('pending fallback is not the old early 800ms release', () {
      expect(
        SeekProgressGuard.pendingSeekFallbackDelay,
        greaterThan(const Duration(milliseconds: 800)),
      );
    });

    test(
      'positionStream at 0 does not count as reached before seek settles',
      () {
        expect(
          SeekProgressGuard.positionReachedTarget(
            position: Duration.zero,
            target: const Duration(minutes: 2),
            total: const Duration(minutes: 10),
          ),
          isFalse,
        );
      },
    );

    test('target is reached inside tolerance', () {
      expect(
        SeekProgressGuard.positionReachedTarget(
          position: const Duration(minutes: 2, milliseconds: 100),
          target: const Duration(minutes: 2),
          total: const Duration(minutes: 10),
        ),
        isTrue,
      );
    });

    test('slider value is clamped to the playable duration', () {
      expect(
        SeekProgressGuard.targetFromSliderValue(
          value: 1.4,
          total: const Duration(minutes: 5),
        ),
        const Duration(minutes: 5),
      );
      expect(
        SeekProgressGuard.targetFromSliderValue(
          value: -0.2,
          total: const Duration(minutes: 5),
        ),
        Duration.zero,
      );
    });
  });
}
