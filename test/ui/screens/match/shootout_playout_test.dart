/// **THE SHOOTOUT IS PLAYED OUT, kick by kick, in the commentary.**
///
/// Asked for from the couch, in these words: at the end of the game it is meant
/// to come up with commentary saying it is going to penalties, then proceed to
/// do the penalties one at a time with the score recorded as `0(3)-(2)0` —
/// "that's how it has always worked and how it should work now".
///
/// And then, on seeing the first pass go straight to the result: "there should
/// be some tension... so it's player a steps up.... pause.... goal.... etc for
/// all". **A KICK IS TWO BEATS**, and the gap between them is the feature. The
/// tests below are written around that pair — a walk-up with the score as it
/// stands, a beat of nothing, then the outcome and the bracket moving.
///
/// The JS did exactly that. `shootout_row.dart`'s own header records the port
/// dropping the reveal on the reasoning that its copy was hardcoded English
/// with no `t()` key behind it and the catalogues are generated, so there was
/// nothing to port — which was true of the COPY and was allowed to decide the
/// BEHAVIOUR. Copy this repo owns is written in `en_copy.dart` and its nine
/// now, so the reveal is buildable and is built.
///
/// **The clock is RUN rather than skipped**, which is the whole point: the
/// existing cup tests all reach full time through `skipToEnd`, and a shootout
/// that only ever arrives at once is exactly the thing being fixed.
///
/// The harness is `match_screen_test.dart`'s own — `pumpMatch`, `squadSave`,
/// `stateOf` — imported rather than copied.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart' show t;
import 'package:merge_empire_fc/providers/game_providers.dart'
    show gameProvider;
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart';
import 'package:merge_empire_fc/ui/screens/squad/player_detail_sheet.dart'
    show cardById;
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart'
    show MatchScreenState;

import 'match_screen_test.dart';

/// A cup tie that finished GOALLESS and was settled from twelve yards.
///
/// **Goalless because the clock has to be WATCHED here.** A goal cuts to the 2D
/// pitch and the cutaway stops the clock until it has played out — which is the
/// screen being right, and it means a fixture with goals in it cannot be pumped
/// minute by minute the way these tests need. Nothing about a shootout depends
/// on the ninety minutes having goals in them, and `0 (3) - (2) 0` is the shape
/// the couch asked for anyway.
///
/// The shootout's winning goal is folded into `homeGoals` by the engine so its
/// `won` and its scoreline agree — see `cup_launcher` — and the feed carries
/// the ninety minutes only, which is why the board plays out 0-0.
///
/// Without [suddenDeath] it is three each and then the fourth kick, which is
/// eight kicks; with it, five each and then one apiece.
Map<String, dynamic> _tie({bool won = true, bool suddenDeath = false}) {
  final kicks = <Map<String, dynamic>>[
    for (var i = 0; i < (suddenDeath ? 5 : 3); i++) ...[
      {'team': 'home', 'scored': true},
      {'team': 'away', 'scored': true},
    ],
    {'team': 'home', 'scored': won, if (suddenDeath) 'suddenDeath': true},
    {'team': 'away', 'scored': !won, if (suddenDeath) 'suddenDeath': true},
  ];
  var ours = 0;
  var theirs = 0;
  for (final k in kicks) {
    if (k['scored'] != true) continue;
    if (k['team'] == 'home') {
      ours++;
    } else {
      theirs++;
    }
  }
  return {
    ...matchResult(
      fixtureKey: 's1_m44',
      isHome: true,
      addedTime: 0,
      events: const <Map<String, dynamic>>[],
    ),
    'isCup': true,
    'clubName': 'Testville',
    'opponentName': 'Ayton',
    // The folded scoreline: a 0-0 with the shootout's goal in it.
    'homeGoals': won ? 1 : 0,
    'awayGoals': won ? 0 : 1,
    'won': won,
    'drawn': false,
    'opponentRating': 60,
    'penaltyShootout': <String, dynamic>{
      'playerWins': won,
      'homeScore': ours,
      'awayScore': theirs,
      'kicks': kicks,
    },
  };
}

/// Watch the ninety minutes out, one minute at a time, and stop on the tick
/// that reaches the whistle. Nothing is skipped: the shootout, if there is one,
/// is exactly one beat old when this returns.
Future<void> _watchToTheWhistle(
  WidgetTester tester,
  MatchScreenState state,
) async {
  const minute = Duration(milliseconds: matchMinuteMs);
  for (var i = 0; i < 200 && state.frame.minute < 90; i++) {
    await tester.pump(minute);
  }
  // The clock is ON ninety; the NEXT tick is the one that decides what happens
  // at the whistle.
  await tester.pump(minute);
}

/// Let the kicks run out.
///
/// **`pumpAndSettle` cannot do this on its own**: the shootout is a chain of
/// timers with a settled frame between each pair, so the settle loop sees no
/// scheduled frame and returns between kicks. Pumping the beat is what the
/// player waiting is.
Future<void> _playOutTheKicks(
  WidgetTester tester,
  MatchScreenState state,
) async {
  for (var i = 0; i < 120 && !state.frame.finished; i++) {
    await tester.pump(penaltyStepUpBeat);
  }
  await tester.pumpAndSettle();
}

/// The feed rows currently BUILT, newest first — the list is newest-at-index-0
/// and a `ListView.builder` only builds what fits.
List<String> _onScreen(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(
      of: find.byKey(const ValueKey('match-feed')),
      matching: find.byType(Text),
    ),
  ))
    t.data ?? '',
];

/// Every shootout line the screen has written, in order — see
/// `MatchScreenState.notes`. Used where a long shootout would push its own
/// first kicks off the bottom of the viewport.
List<String> _pensKeys(MatchScreenState state) => [
  for (final line in state.notes)
    if (line.type == 'penalty') line.key,
];

/// Who each shootout row names — the man on the spot, or the club when the
/// save has nobody to name.
List<String> _pensWho(MatchScreenState state) => [
  for (final line in state.notes)
    if (line.type == 'penalty') '${line.params['who']}',
];

/// The bracket the BOARD is carrying — ours and theirs.
///
/// **The rows do not print a score any more.** It was in the head of every one
/// of them and it is on the board in three times the type; reported off the
/// first screenshot: "the score isn't needed there as it's at the top." So the
/// running tally is asserted where a player actually reads it.
(String, String) _bracket(WidgetTester tester) => (
  (tester
          .widget<Text>(find.byKey(const ValueKey('match-pens-left')))
          .data) ??
      '',
  (tester
          .widget<Text>(find.byKey(const ValueKey('match-pens-right')))
          .data) ??
      '',
);

void main() {
  group('A SHOOTOUT IS PLAYED OUT RATHER THAN SUMMARISED', () {
    testWidgets('the whistle announces it, and no kick has been taken yet', (
      tester,
    ) async {
      await pumpMatch(tester, _tie(), save: squadSave());
      final state = stateOf(tester);
      await _watchToTheWhistle(tester, state);

      expect(_pensKeys(state), ['match.pens.going']);
      // On the feed, in words. The sentence is one of a pool of three and the
      // row carries no heading to assert instead — see `match.pens.going` and
      // the note on the row's plate — so all three are named here.
      expect(
        _onScreen(tester).any(
          (s) =>
              s.contains('penalties') ||
              s.contains('spot kicks') ||
              s.contains('twelve yards'),
        ),
        isTrue,
        reason: 'the ninety minutes ended with nothing said about a shootout',
      );
      // **AND THE MATCH IS NOT OVER.** `finished` is what turns the control
      // row into CONTINUE and puts the write-up at the head of the feed; both
      // over a shootout in progress are the screen saying the tie is done.
      expect(state.frame.finished, isFalse);
      expect(find.byKey(const ValueKey('match-continue')), findsNothing);
      expect(find.byKey(const ValueKey('match-full-time')), findsNothing);
      // The board says which passage this is, and carries no bracket until a
      // kick has actually been struck.
      expect(find.byKey(const ValueKey('match-pens-label')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-pens-left')), findsNothing);

      await _playOutTheKicks(tester, state);
      await settleSave(tester);
    });

    testWidgets('THEN ONE KICK AT A TIME, with the score recorded', (
      tester,
    ) async {
      await pumpMatch(tester, _tie(), save: squadSave());
      final state = stateOf(tester);
      await _watchToTheWhistle(tester, state);

      // **THE OPENING PAUSE, THEN SOMEBODY WALKS UP — and that is all.**
      // The kick has not been taken: the row says who is on the spot and the
      // score as he places the ball, which is nil-nil from twelve yards.
      await tester.pump(penaltyOpenBeat);
      expect(_pensKeys(state), ['match.pens.going', 'match.pens.step_up']);
      // **A REAL NAME OFF THE TEAM SHEET, not the club.** The engine's
      // shootout names nobody — it decides each kick off the two ratings — so
      // the taker is the screen's, read from the eleven who finished the
      // match.
      expect(_pensWho(state).last, isNotEmpty);
      expect(_pensWho(state).last, isNot('Testville'));
      expect(_onScreen(tester).any((s) => s.contains(_pensWho(state).last)),
          isTrue);
      // The bracket is on the board from the moment he stands over it.
      expect(_bracket(tester), ('(0)', '(0)'));

      // **AND NOW THE PAUSE.** Half a beat later he still has not kicked it,
      // and nothing on the page has moved.
      await tester.pump(penaltyStepUpBeat ~/ 2);
      expect(_pensKeys(state).length, 2);
      expect(_bracket(tester), ('(0)', '(0)'));

      // Then he strikes it, and the bracket moves.
      await tester.pump(penaltyStepUpBeat);
      expect(_pensKeys(state).last, 'match.pens.scored');
      expect(_bracket(tester), ('(1)', '(0)'));

      // And theirs walks up next — the walk-up moves nothing, because the
      // score while somebody is standing over the ball is the score before he
      // kicks it.
      await tester.pump(penaltyKickBeat);
      expect(_pensKeys(state).last, 'match.pens.opp_step_up');
      expect(_bracket(tester), ('(1)', '(0)'));
      expect(state.frame.finished, isFalse);

      // The rest of them, and the tie is settled.
      await _playOutTheKicks(tester, state);
      expect(state.frame.finished, isTrue);
      expect(find.byKey(const ValueKey('match-full-time')), findsOneWidget);
      // Four each and the eighth kick missed: 4-3 on the board's bracket.
      expect(_bracket(tester), ('(4)', '(3)'));
      // **EVERY KICK IS A PAIR.** Eight kicks, so sixteen rows, plus the
      // announcement and the verdict.
      expect(
        _pensKeys(state).where((k) => k.endsWith('step_up')).length,
        8,
      );
      expect(_pensKeys(state).length, 18);
      // The ninety minutes are untouched by any of it.
      expect(state.frame.ourGoals, 0);
      expect(state.frame.theirGoals, 0);
      // And it closes on which way the kicks went.
      expect(_pensKeys(state).last, 'match.pens.through');
      await settleSave(tester);
    });

    testWidgets('AND THERE IS NOTHING LEFT TO MANAGE WHILE IT RUNS', (
      tester,
    ) async {
      // **Caught on the first screenshot of the feature**, which is what a
      // screenshot is for: the tactic strip, the boost strip and the SUBS
      // button were all still live over a shootout, because every one of them
      // is gated on `finished` and `finished` is false while the kicks are
      // being taken. That is the screen offering three things the laws of the
      // game do not allow — you cannot switch to Attack, call a Crowd Roar or
      // bring somebody on once the whistle has gone.
      //
      // The eleven who finished the match are the eleven who take the kicks,
      // which `_penaltyTakers` has already read off the team sheet, so a
      // substitution here would make the taker list a lie as well.
      await pumpMatch(tester, _tie(), save: squadSave());
      final state = stateOf(tester);

      // All three are there while the match is being played.
      expect(find.byKey(const ValueKey('match-subs')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-tactic-strip')), findsOneWidget);

      await _watchToTheWhistle(tester, state);
      expect(state.frame.finished, isFalse, reason: 'not the full-time state');
      expect(find.byKey(const ValueKey('match-subs')), findsNothing);
      expect(find.byKey(const ValueKey('match-tactic-strip')), findsNothing);
      // The two that DO still make sense: the beats scale with the pace, so a
      // player who wants the kicks quicker can have them, and skip is the same
      // offer it always was.
      expect(find.byKey(const ValueKey('match-speed')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-skip')), findsOneWidget);

      await _playOutTheKicks(tester, state);
      await settleSave(tester);
    });

    testWidgets('A KICK TAKEN IS A GOAL CARD, with the taker on it', (
      tester,
    ) async {
      // Asked for off the second screenshot: "the way we do goal now is how I
      // want it, with player image, with Goal as title etc. It should look
      // similar." So a kick that is taken goes through the same branch a goal
      // in open play does — the face, the name, the heading, the sentence as
      // its caption — and the walk-up before it stays a plain line, because
      // three cards a kick would be all shout and no pause.
      await pumpMatch(tester, _tie(), save: squadSave());
      final state = stateOf(tester);
      await _watchToTheWhistle(tester, state);
      await tester.pump(penaltyOpenBeat);

      // The walk-up carries the man but is not a card.
      final walkUp = state.notes.last;
      expect(walkUp.key, 'match.pens.step_up');
      expect(walkUp.goal, isNull);
      expect(walkUp.aboutId, isNotNull);

      // The kick is.
      await tester.pump(penaltyStepUpBeat);
      final kick = state.notes.last;
      expect(kick.key, 'match.pens.scored');
      expect(kick.goal, isNotNull);
      // **`ours` MEANS ONE OF OURS TOOK IT**, which is what picks the green —
      // a green card reading "Missed" was the first attempt at colouring these
      // by who the news was good for, and it read as good news about a
      // failure.
      expect(kick.goal!.ours, isTrue);
      // The same man walked up and took it.
      expect(kick.aboutId, walkUp.aboutId);
      // The heading is the goal card's own word, and the SCORE is not on it:
      // the board carries the bracket.
      expect(find.text(t('match.goal_card.title')), findsWidgets);

      // And a kick of theirs is a card with no face to put on it — the engine
      // names no opposition player and never has.
      // Their man walks up, then takes it.
      await tester.pump(penaltyKickBeat);
      await tester.pump(penaltyStepUpBeat);
      final theirs = state.notes.last;
      expect(theirs.key, anyOf('match.pens.opp_scored', 'match.pens.opp_missed'));
      expect(theirs.goal!.ours, isFalse);
      expect(theirs.aboutId, isNull);

      await _playOutTheKicks(tester, state);
      await settleSave(tester);
    });

    testWidgets('a tie LOST on penalties says so', (tester) async {
      await pumpMatch(tester, _tie(won: false), save: squadSave());
      final state = stateOf(tester);
      await _watchToTheWhistle(tester, state);
      await _playOutTheKicks(tester, state);
      expect(_pensKeys(state).last, 'match.pens.out');
      expect(_bracket(tester), ('(3)', '(4)'));
      await settleSave(tester);
    });

    testWidgets('and sudden death is named when it arrives', (tester) async {
      await pumpMatch(tester, _tie(suddenDeath: true), save: squadSave());
      final state = stateOf(tester);
      await _watchToTheWhistle(tester, state);
      await _playOutTheKicks(tester, state);
      // Five each before it, so the announcement lands on the eleventh kick —
      // ONCE, not before every kick after it. The sixth kick reading exactly
      // like the fifth is what it is there to stop.
      expect(
        _pensKeys(state).where((k) => k == 'match.pens.sudden_death').length,
        1,
      );
      expect(
        _pensKeys(state).indexOf('match.pens.sudden_death'),
        // The announcement, then ten kicks of two rows each — and it lands
        // BEFORE the eleventh man walks up, because it is what he is carrying
        // out to the spot with him.
        21,
      );
      expect(_pensKeys(state)[22], 'match.pens.step_up');
      await settleSave(tester);
    });

    testWidgets('the order walks down the team sheet, the keeper last', (
      tester,
    ) async {
      // **THE TAKER IS THE SCREEN'S, and the order is the team sheet's.** The
      // engine decides each kick off the two sides' ratings and names nobody,
      // so who walks up is the port's own — the eleven who FINISHED the match,
      // outfield first and the goalkeeper last, because a sudden death has to
      // run a long way before it reaches him.
      final container = await pumpMatch(
        tester,
        _tie(suddenDeath: true),
        save: squadSave(),
      );
      final state = stateOf(tester);
      await _watchToTheWhistle(tester, state);
      await _playOutTheKicks(tester, state);

      // Six kicks of ours, and the walk-up and the result name the same man.
      final ours = <String>[];
      var i = 0;
      for (final line in state.notes) {
        if (line.type != 'penalty') continue;
        if (line.key == 'match.pens.step_up') {
          ours.add('${line.params['who']}');
        }
        if (line.key == 'match.pens.scored' || line.key == 'match.pens.missed') {
          expect('${line.params['who']}', ours[i++]);
        }
      }
      expect(ours.length, 6);
      // **AND IT WALKS DOWN THE SHEET** rather than handing the ball to the
      // same man six times. (The harness's eleven share four definitions, so
      // two takers can genuinely have the same NAME — what is asserted is that
      // the order advances, not that every name is distinct.)
      expect(ours.first, isNot(ours.last));
      // **THE GOALKEEPER IS LAST**, which is the only thing about the order
      // that is a decision rather than the team sheet's own. He is eleventh,
      // so six kicks never reach him — a long enough sudden death would.
      final keeper = cardById(container.read(gameProvider).state, 'c0')?.name();
      expect(keeper, isNotNull);
      expect(ours, isNot(contains(keeper)));
      await settleSave(tester);
    });

    testWidgets('A SKIPPED TIE IS THE SAME RECORD, taken all at once', (
      tester,
    ) async {
      // The 13 Sep audit's rule: what was watched is what gets recorded, and a
      // skip may not produce a different match. The kicks are all there and
      // the board carries the full bracket; only the pacing is gone.
      await pumpMatch(tester, _tie(), save: squadSave());
      final state = stateOf(tester);
      state.skipToEnd();
      await tester.pumpAndSettle();

      expect(state.frame.finished, isTrue);
      expect(_pensKeys(state).first, 'match.pens.going');
      expect(_pensKeys(state)[1], 'match.pens.step_up');
      expect(_pensKeys(state).last, 'match.pens.through');
      // Both beats of every kick, exactly as a watched tie writes them.
      expect(_pensKeys(state).length, 18);
      expect(_bracket(tester), ('(4)', '(3)'));
      expect(find.byKey(const ValueKey('shootout-row')), findsOneWidget);
      await settleSave(tester);
    });

    testWidgets('and a LEAGUE match still ends at the whistle', (tester) async {
      // The control. Nothing outside a cup carries a shootout, and a level
      // league match is over when the ninety minutes are.
      await pumpMatch(
        tester,
        matchResult(fixtureKey: 's1_m44', addedTime: 0),
        save: squadSave(),
      );
      final state = stateOf(tester);
      await _watchToTheWhistle(tester, state);
      expect(state.frame.finished, isTrue);
      expect(_pensKeys(state), isEmpty);
      expect(find.byKey(const ValueKey('match-pens-label')), findsNothing);
      expect(find.byKey(const ValueKey('match-pens-left')), findsNothing);
      await tester.pumpAndSettle();
      await settleSave(tester);
    });
  });
}
