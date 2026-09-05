/// The onboarding trail, on screen. The other half of
/// `engine/coach_guide_engine.dart`.
///
/// **Which marker is live is the engine's question; WHERE it is said and WHAT
/// spends it are this file's.** A guide reaches the player two ways and they are
/// the same sentence in both:
///
/// - **Colin says it.** On the four tabs that have a floating head he is the one
///   who says it, ahead of his own commentary — see `coach_tips.dart`. On the
///   home screen he has a dock orb instead, so it goes to the front of that
///   orb's pool — see `screens/home/coach_bubble.dart`. Two surfaces because
///   there are two Colins, not because there are two messages.
/// - **The bottom bar points at it.** The tab the marker names wears a slow ring
///   until the player goes there — see `tab_bar.dart`. That is what the coach
///   card at the end of the tutorial cannot do: name a control and leave the
///   player looking for it.
///
/// **A marker is spent by a REAL control being used**, and every one of those
/// reports through [reportCoachGuide]: arriving on a tab, the Dugout opening, a
/// training session opening. Nothing spends a marker for having been shown it.
/// The calls live in `app_shell.dart` beside the other bus routes — a tab
/// change in `_applyTab`, and `nav:quicknav` and `nav:subtab` in its `build`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/coach_guide_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';

/// The live marker's id, or null. **The ID rather than the record**, because
/// `savePick` hands back the previous value when the new one compares equal and
/// a `String?` is the cheapest thing there is to compare.
final activeCoachGuideIdProvider = savePick<String?>(
  (s) => nextCoachGuide(s)?.id,
);

/// The live marker itself.
final activeCoachGuideProvider = Provider<CoachGuide?>((ref) {
  final id = ref.watch(activeCoachGuideIdProvider);
  if (id == null) return null;
  for (final guide in coachGuides) {
    if (guide.id == id) return guide;
  }
  return null;
});

/// Which tab the bottom bar should be nudging, or null.
final coachGuideNudgeProvider = Provider<ShellTab?>((ref) {
  final destination = ref.watch(activeCoachGuideProvider)?.destination;
  if (destination == null) return null;
  for (final tab in ShellTab.values) {
    if (tab.name == destination) return tab;
  }
  return null;
});

/// The player used a control that spends a marker.
///
/// Guarded rather than written blind: see [coachGuidePending] for why a tab
/// change must not schedule a save on a manager who left the trail behind
/// fifteen seasons ago.
void reportCoachGuide(WidgetRef ref, String trigger) {
  final game = ref.read(gameProvider);
  if (!coachGuidePending(game.state, trigger)) return;
  game.update((s) => completeCoachGuides(s, trigger));
}
