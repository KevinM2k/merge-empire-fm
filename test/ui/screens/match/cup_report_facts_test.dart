/// What the write-up is told about a CUP TIE, and the two things it was not.
///
/// **A cup tie decided on penalties reached the report as a draw between two
/// clubs who both had a next round.** Reported from the couch with the shot: a
/// cup tie, full time, 1-1, "why no penalties". Two separate faults in the
/// same paragraph, and both of them live in `reportFactsFor` rather than in the
/// engine — the port's divergences belong on the screen, and
/// `match_orchestration_parity_test` compares the result object field for
/// field.
///
/// 1. `ReportFacts` had no shootout field at all, so the headline came off the
///    margin and the margin says a level scoreline is a draw.
/// 2. `oppNextOpponent` is a lookup against the LEAGUE schedule, and a cup
///    opponent can be a club from that league — so the tie closed on
///    `report.next.*_both`, naming a fixture for each of the two clubs "in the
///    next round" moments after one of them had gone out. `_nextFor`'s own doc
///    has always said it is null for a cup tie; nothing made it so.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/match_report.dart';
import 'package:merge_empire_fc/engine/season_fixtures.dart';
import 'package:merge_empire_fc/ui/screens/match/match_report_card.dart';

Map<String, dynamic> _save() {
  final s =
      jsonDecode(
            File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
          )['state']
          as Map<String, dynamic>;
  final prog = s['progression'] as Map<String, dynamic>;
  prog['seasonMatchesPlayed'] = 4;
  prog['seasonComplete'] = false;
  prog['seasonOpponents'] = ['Ayton', 'Beeches', 'Cadley', 'Deeping'];
  prog['seasonFixtures'] = null;
  generateSeasonFixtures(s);
  return s;
}

/// A tie that finished level and was settled from twelve yards. The shootout's
/// winning goal is folded into `homeGoals` by the engine — see `cup_launcher` —
/// and the feed carries the ninety minutes only.
///
/// The opponent is a club from the player's own division on purpose: that is
/// what makes the league schedule answer "who do they play next", which is the
/// second fault.
Map<String, dynamic> _tie({bool won = true, bool isCup = true}) => {
  'clubName': 'Testville',
  'opponentName': 'Ayton',
  'isHome': true,
  'isCup': isCup,
  'homeGoals': won ? 2 : 1,
  'awayGoals': won ? 1 : 2,
  'won': won,
  'drawn': false,
  'events': [
    {'minute': 22, 'type': 'goal', 'team': 'home', 'scorer': 'Smith'},
    {'minute': 61, 'type': 'goal', 'team': 'away'},
  ],
  'penaltyShootout': <String, dynamic>{
    'playerWins': won,
    'homeScore': won ? 4 : 3,
    'awayScore': won ? 3 : 4,
    'kicks': <Map<String, dynamic>>[
      for (var i = 0; i < 4; i++) {'team': 'home', 'scored': won || i < 3},
      for (var i = 0; i < 4; i++) {'team': 'away', 'scored': !won || i < 3},
    ],
  },
};

void main() {
  test('THE WRITE-UP IS TOLD THE TIE WENT TO PENALTIES', () {
    final save = _save();
    final facts = reportFactsFor(_tie(), save, const []);
    expect(facts, isNotNull);
    expect(facts!.shootout, isNotNull);
    // The kicks scored, our side first, and who went through — `shootoutFrom`
    // already knows that `home` is always ours.
    expect(facts.shootout!.ours, 4);
    expect(facts.shootout!.theirs, 3);
    expect(facts.shootout!.won, isTrue);

    // And the paragraph opens on it rather than on "they share the points".
    final keys = [for (final b in buildMatchReport(facts)) b.key];
    expect(keys, contains('report.cup.pens_won'));
    expect(keys.where((k) => k.startsWith('report.draw.')), isEmpty);
  });

  test('and which way the kicks went', () {
    final facts = reportFactsFor(_tie(won: false), _save(), const [])!;
    expect(facts.shootout!.won, isFalse);
    expect(
      [for (final b in buildMatchReport(facts)) b.key],
      contains('report.cup.pens_lost'),
    );
  });

  test('IT DOES NOT SEND THE BEATEN CLUB INTO THE NEXT ROUND', () {
    final save = _save();
    final facts = reportFactsFor(_tie(), save, const [])!;
    expect(
      facts.oppNextOpponent,
      isNull,
      reason: 'a cup tie closed by naming a next fixture for BOTH clubs',
    );
    // Ours is still a fact and is still printed — it is the league game that
    // follows the tie, which is what the singular pool says.
    expect(facts.nextOpponent, isNotNull);
    expect(
      [for (final b in buildMatchReport(facts)) b.key],
      isNot(contains('report.next.away_both')),
    );
  });

  test('and a LEAGUE match still tells the reader about both of them', () {
    // The control, and the reason this is gated on `isCup` rather than
    // deleted: the pairing was asked for from the couch — "a summary about the
    // game for anyone reading it" — and a league fixture is where it is true.
    final save = _save();
    final league = _tie()
      ..['isCup'] = false
      ..remove('penaltyShootout');
    final facts = reportFactsFor(league, save, const [])!;
    expect(facts.shootout, isNull);
    expect(facts.oppNextOpponent, isNotNull);
  });
}
