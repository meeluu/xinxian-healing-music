/// One-shot warm reload rules for the local quick soothing player.
///
/// This is a temporary Flutter Web workaround: the first uncached local audio
/// player instance may not be seek-ready even after the page renders, while a
/// second construction behaves normally. Keep the decision small and testable.
class PlayerWarmReloadDecision {
  PlayerWarmReloadDecision._();

  static const Duration delay = Duration(milliseconds: 500);

  static bool shouldWarmReload({
    required bool enabled,
    required bool alreadyReloaded,
  }) {
    return enabled && !alreadyReloaded;
  }
}
