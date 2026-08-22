/// Coach Colin's read on the history between two clubs.
///
/// **Fourteen `manager_hint.*` strings, translated into ten languages, with
/// nothing able to print one** — while the surface they belong to had existed
/// the whole time. `coach_bubble.dart`'s own header says it is the port of
/// `_computeManagerTips`, which is the JS function these are the output of.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/manager_hint_engine.dart';

/// A save with these results already played, in the order given.
Map<String, dynamic> saveWith(
  List<({int season, int match, String opp, int ours, int theirs})> played,
) => {
  'progression': <String, dynamic>{
    'seasonCount': 3,
    'fixtureResults': <String, dynamic>{
      for (final p in played)
        's${p.season}_m${p.match}': <String, dynamic>{
          'homeGoals': p.ours,
          'awayGoals': p.theirs,
          'won': p.ours > p.theirs,
          'drawn': p.ours == p.theirs,
          'isHome': true,
          'opponentName': p.opp,
        },
    },
  },
};

({int season, int match, String opp, int ours, int theirs}) win(
  int season,
  int match, [
  String opp = 'Rivals',
]) => (season: season, match: match, opp: opp, ours: 2, theirs: 0);

({int season, int match, String opp, int ours, int theirs}) loss(
  int season,
  int match, [
  String opp = 'Rivals',
]) => (season: season, match: match, opp: opp, ours: 0, theirs: 2);

({int season, int match, String opp, int ours, int theirs}) draw(
  int season,
  int match, [
  String opp = 'Rivals',
]) => (season: season, match: match, opp: opp, ours: 1, theirs: 1);

void main() {
  group('who we have played', () {
    test('ONLY THIS OPPONENT, and oldest first', () {
      final s = saveWith([
        win(3, 5),
        loss(2, 1, 'Someone Else'),
        win(2, 8),
        draw(1, 2),
      ]);
      final m = meetingsWith(s, 'Rivals');
      expect(m.map((x) => '${x.season}/${x.matchNum}'), ['1/2', '2/8', '3/5']);
    });

    test('and the ORDER is the key, not the map', () {
      // A save's map order is whatever the JSON round-trip produced. "Our last
      // two against them" read off an unsorted list is two arbitrary matches,
      // and it would pass any test whose fixture happened to be in order.
      final s = saveWith([win(1, 1), loss(3, 9), draw(2, 4)]);
      final m = meetingsWith(s, 'Rivals');
      expect(m.first.season, 1);
      expect(m.last.season, 3);
      expect(m.last.won, isFalse);
    });

    test('a cup tie is not this fixture\'s history', () {
      // Cup ties are keyed differently, and a run against a club in the league
      // is not a run that includes a one-off knockout.
      final s = saveWith([win(2, 1)]);
      (s['progression'] as Map<String, dynamic>)['fixtureResults']['cup_r2'] = {
        'homeGoals': 5,
        'awayGoals': 0,
        'won': true,
        'drawn': false,
        'opponentName': 'Rivals',
      };
      expect(meetingsWith(s, 'Rivals'), hasLength(1));
    });

    test('and an unknown club, a null one or an empty save has none', () {
      expect(meetingsWith(saveWith([win(1, 1)]), 'Nobody'), isEmpty);
      expect(meetingsWith(saveWith([win(1, 1)]), null), isEmpty);
      expect(meetingsWith(null, 'Rivals'), isEmpty);
      expect(meetingsWith(<String, dynamic>{}, 'Rivals'), isEmpty);
    });
  });

  group('the run', () {
    test('counts back from the LAST meeting', () {
      expect(streakLength(meetingsWith(saveWith([
        loss(1, 1), win(1, 2), win(1, 3), win(1, 4),
      ]), 'Rivals')), 3);
    });

    test('A DRAW ENDS A RUN rather than extending it', () {
      // Three wins either side of a draw is not a run of six, and a draw as the
      // last result is not a run at all.
      expect(streakLength(meetingsWith(saveWith([
        win(1, 1), win(1, 2), draw(1, 3), win(1, 4), win(1, 5),
      ]), 'Rivals')), 2);
      expect(streakLength(meetingsWith(saveWith([
        win(1, 1), win(1, 2), draw(1, 3),
      ]), 'Rivals')), 0);
    });

    test('and it runs across a season boundary', () {
      // `fixtureResults` is cleared by a PRESTIGE reset, not by a rollover, so
      // a hold over a club is allowed to outlive a season.
      expect(streakLength(meetingsWith(saveWith([
        win(1, 13), win(2, 2), win(3, 1),
      ]), 'Rivals')), 3);
    });

    test('an empty history is not a run of nothing', () {
      expect(streakLength(const []), 0);
    });
  });

  group('how long ago', () {
    test('names the season in the player\'s own terms', () {
      expect(whenPlayed(3, 3).key, 'manager_hint.when.this_season');
      expect(whenPlayed(2, 3).key, 'manager_hint.when.last_season');
      expect(whenPlayed(1, 3).key, 'manager_hint.when.n_seasons_back');
      expect(whenPlayed(1, 3).params['n'], 2);
    });

    test('and a season somehow ahead reads as this one', () {
      expect(whenPlayed(9, 3).key, 'manager_hint.when.this_season');
    });
  });

  group('what he says about it', () {
    ManagerHint? hint(List<({int season, int match, String opp, int ours, int theirs})> p) =>
        headToHeadHint(saveWith(p), 'Rivals', currentSeason: 3);

    test('A RUN OF THREE IS THE HEADLINE, whichever way it went', () {
      expect(hint([win(1, 1), win(1, 2), win(1, 3)])?.key,
          'manager_hint.streak.win.3plus');
      expect(hint([loss(1, 1), loss(1, 2), loss(1, 3), loss(1, 4)])?.key,
          'manager_hint.streak.loss.3plus');
      expect(hint([loss(1, 1), loss(1, 2), loss(1, 3), loss(1, 4)])?.params['n'], 4);
    });

    test('a run of two is its own, quieter line', () {
      expect(hint([loss(1, 1), win(1, 2), win(1, 3)])?.key,
          'manager_hint.streak.win.2');
      expect(hint([win(1, 1), loss(1, 2), loss(1, 3)])?.key,
          'manager_hint.streak.loss.2');
    });

    test('and one meeting is the SCORE and when it was', () {
      final h = hint([draw(2, 4)]);
      expect(h?.key, 'manager_hint.last_meeting.drawn');
      expect(h?.params['lastScore'], '1-1');
      expect((h?.params['when']! as ManagerHint).key,
          'manager_hint.when.last_season');
    });

    test('THE SCORE READS OUR WAY ROUND, whatever the venue was', () {
      // `homeGoals` in a stored result is OURS however the match was played —
      // the same convention the fixtures sheet orients around — and every one
      // of these sentences is written that way: "Beat {opp} 3-1".
      final h = headToHeadHint(
        saveWith([(season: 3, match: 1, opp: 'Rivals', ours: 3, theirs: 1)]),
        'Rivals',
        currentSeason: 3,
      );
      expect(h?.key, 'manager_hint.last_meeting.won');
      expect(h?.params['lastScore'], '3-1');
    });

    test('a club we have never played gets no line at all', () {
      expect(headToHeadHint(saveWith([win(1, 1)]), 'Strangers', currentSeason: 3),
          isNull);
      expect(headToHeadHint(null, 'Rivals', currentSeason: 3), isNull);
    });

    test('and the opponent is named in every line it can produce', () {
      for (final p in [
        [win(1, 1), win(1, 2), win(1, 3)],
        [win(1, 1), win(1, 2)],
        [draw(1, 1)],
        [loss(1, 1)],
      ]) {
        expect(hint(p)?.params['opp'], 'Rivals');
      }
    });
  });
}
