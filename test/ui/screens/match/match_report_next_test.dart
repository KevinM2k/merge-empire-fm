/// Who the write-up says we play next — and that it says nobody once the
/// season is over.
///
/// **THE LAST MATCH OF A SEASON NAMED AN OPPONENT.** `previewFixture` indexes
/// the schedule as `seasonMatchesPlayed % opponentsPerSeason`, so on the
/// fourteenth match that wraps to 0 and the preview happily reports the
/// season's FIRST opponent — a fixture already played, in a season that has
/// just ended. The report card printed it as the next game. Reported from the
/// couch.
///
/// The wrap is the JS's (`matchEngine.js`'s `previewFixture` does the same
/// arithmetic) and `fixture_preview_reference.json` compares that function
/// field for field, so the guard is on the SCREEN — `reportFactsFor` — where
/// the port's other divergences live.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/ui/screens/match/match_report_card.dart';

/// The same realistic save the quest and preview fixtures ship.
Map<String, dynamic> _save() =>
    jsonDecode(
          File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
        )['state']
        as Map<String, dynamic>;

Map<String, dynamic> _prog(Map<String, dynamic> s) =>
    s['progression'] as Map<String, dynamic>;

/// A settled 1–0 with one goal on it, which is all the facts builder needs.
Map<String, dynamic> _result(Map<String, dynamic> save) => {
  'clubName': '${save['clubName']}',
  'opponentName': 'Regional League 2',
  'isHome': true,
  'isCup': false,
  'homeGoals': 1,
  'awayGoals': 0,
  'events': [
    {'minute': 30, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
  ],
};

void main() {
  test('mid-season, the report knows who is next', () {
    final save = _save();
    _prog(save)['seasonMatchesPlayed'] = 3;
    _prog(save)['seasonComplete'] = false;

    final facts = reportFactsFor(_result(save), save, const []);
    expect(facts, isNotNull);
    expect(facts!.nextOpponent, isNotNull);
    expect(facts.nextOpponent, isNotEmpty);
  });

  test('AND AT THE END OF THE SEASON THERE IS NOBODY NEXT', () {
    final save = _save();
    // Where the final whistle of a season leaves the save: `simulateMatch`
    // counts the match and raises the flag, and `endSeason` has not run yet
    // because the player is still reading this write-up.
    _prog(save)['seasonMatchesPlayed'] = matchesPerSeason;
    _prog(save)['seasonComplete'] = true;

    final facts = reportFactsFor(_result(save), save, const []);
    expect(facts, isNotNull);
    expect(
      facts!.nextOpponent,
      isNull,
      reason: 'the schedule wrapped to the first opponent of the season',
    );
  });
}
