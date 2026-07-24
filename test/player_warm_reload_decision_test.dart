import 'package:flutter_test/flutter_test.dart';
import 'package:xinxian_healing_music/utils/player_warm_reload_decision.dart';

void main() {
  group('PlayerWarmReloadDecision', () {
    test('enabled and not already reloaded triggers one warm reload', () {
      expect(
        PlayerWarmReloadDecision.shouldWarmReload(
          enabled: true,
          alreadyReloaded: false,
        ),
        isTrue,
      );
    });

    test('enabled but already reloaded does not trigger again', () {
      expect(
        PlayerWarmReloadDecision.shouldWarmReload(
          enabled: true,
          alreadyReloaded: true,
        ),
        isFalse,
      );
    });

    test('disabled never triggers warm reload', () {
      expect(
        PlayerWarmReloadDecision.shouldWarmReload(
          enabled: false,
          alreadyReloaded: false,
        ),
        isFalse,
      );
      expect(
        PlayerWarmReloadDecision.shouldWarmReload(
          enabled: false,
          alreadyReloaded: true,
        ),
        isFalse,
      );
    });

    test('replacement screen with disabled flag will not loop', () {
      final firstOpen = PlayerWarmReloadDecision.shouldWarmReload(
        enabled: true,
        alreadyReloaded: false,
      );
      final replacement = PlayerWarmReloadDecision.shouldWarmReload(
        enabled: false,
        alreadyReloaded: true,
      );

      expect(firstOpen, isTrue);
      expect(replacement, isFalse);
    });
  });
}
