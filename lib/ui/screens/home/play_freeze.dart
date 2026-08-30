/// What the Play page keeps showing while a match is being played.
///
/// **THE FIXTURE INDEX MOVES AT KICK-OFF, not at full time.** `simulateMatch`
/// writes `progression.seasonMatchesPlayed` the instant Play is pressed — its
/// own comment says why, and it is right: the cooldown, the fixture list and
/// the placeholder scoreline all need the match to have happened while the
/// popup animates. What it also does is point every provider that reads that
/// figure at the NEXT game, one frame later, while the Play page is still on
/// screen behind the match route's transition. Reported as the next-match
/// card's numbers changing for a second when Play is tapped, and asked to stay
/// away until after the game.
///
/// **The engine is not the place to fix it.** The counter is the JS's and a
/// node fixture pins the orchestration field for field, so the divergence goes
/// on the SCREEN — which is where this port puts them.
///
/// So the page takes a photograph of the fixture it is showing before the
/// whistle and prints that until the whole chain is done. Both halves of it:
/// the card and the caption over it describe ONE fixture, and freezing the card
/// alone would have left "Match 6" sitting over match five's teams.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/screens/home/fixture_caption.dart'
    show FixtureLabel, fixtureLabelProvider;
import 'package:merge_empire_fc/ui/screens/home/next_match_card.dart'
    show NextMatch, nextMatchProvider;

/// The fixture the page was showing when the whistle went.
typedef PlayFreeze = ({NextMatch? match, FixtureLabel label});

/// Null whenever no match is in flight, which is the normal state — the page
/// reads the save directly and this costs nothing.
final playFreezeProvider = NotifierProvider<PlayPageFreeze, PlayFreeze?>(
  PlayPageFreeze.new,
);

class PlayPageFreeze extends Notifier<PlayFreeze?> {
  @override
  PlayFreeze? build() => null;

  /// Take the photograph. Called BEFORE the save is touched — after
  /// `beginMatch` there is nothing left to photograph.
  void hold() {
    if (state != null) return;
    state = (
      match: ref.read(nextMatchProvider),
      label: ref.read(fixtureLabelProvider),
    );
  }

  /// Back to the save. Called once the match's whole chain is done — including
  /// the summary and, on the last match of a season, the season end — because
  /// until then the page is still behind something.
  void release() => state = null;
}
