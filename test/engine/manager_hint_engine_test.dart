/// Coach Colin's read on the history between two clubs.
///
/// **Fourteen `manager_hint.*` strings, translated into ten languages, with
/// nothing able to print one** — while the surface they belong to had existed
/// the whole time. `coach_bubble.dart`'s own header says it is the port of
/// `_computeManagerTips`, which is the JS function these are the output of.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/manager_hint_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

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

    test('IT SUPPLIES EVERY PLACEHOLDER ANY VARIANT COULD ASK FOR', () {
      // **The params a pooled key needs are the UNION across its variants**, and
      // no single variant uses all of them: `streak.win.3plus` has four
      // sentences, one of which never names the club, while another uses only
      // the club. A caller that supplied what one variant needed would leave
      // literal braces in the others — and which variant a player sees depends
      // on a seed, so it would show up as an intermittent bug rather than a
      // broken screen. This is the check that stops that.
      final needed = <String, Set<String>>{
        'manager_hint.streak.win.3plus': {'opp', 'n'},
        'manager_hint.streak.loss.3plus': {'opp', 'n'},
        'manager_hint.streak.win.2': {'opp', 'n'},
        'manager_hint.streak.loss.2': {'opp', 'n'},
        'manager_hint.last_meeting.won': {'opp', 'lastScore', 'when'},
        'manager_hint.last_meeting.drawn': {'opp', 'lastScore', 'when'},
        'manager_hint.last_meeting.lost': {'opp', 'lastScore', 'when'},
      };
      final seen = <String>{};
      for (final p in [
        [win(1, 1), win(1, 2), win(1, 3)],
        [loss(1, 1), loss(1, 2), loss(1, 3)],
        [loss(1, 1), win(1, 2), win(1, 3)],
        [win(1, 1), loss(1, 2), loss(1, 3)],
        [win(1, 1)],
        [draw(1, 1)],
        [loss(1, 1)],
      ]) {
        final h = hint(p)!;
        seen.add(h.key);
        expect(
          h.params.keys.toSet(),
          containsAll(needed[h.key]!),
          reason: h.key,
        );
      }
      // And every key the engine can emit was actually exercised above, so a
      // key nobody reached cannot pass this by never being checked.
      expect(seen, needed.keys.toSet());
    });

    test('and the opponent is named where the line names one', () {
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

  group('the all-time record', () {
    ({String? key, int wins, int draws, int losses}) rec(
      List<({int season, int match, String opp, int ours, int theirs})> p,
    ) => recordFor(meetingsWith(saveWith(p), 'Rivals'));

    test('counts what happened, whatever it says about it', () {
      final r = rec([win(1, 1), draw(1, 2), loss(1, 3), win(1, 4)]);
      expect((r.wins, r.draws, r.losses), (2, 1, 1));
    });

    test('THE MARGIN IS TWO CLEAR, and one ahead is not a record', () {
      // `wins > losses + 1` is the spec's, and one either way is a club you
      // have shared the points with rather than one you own.
      expect(rec([win(1, 1), win(1, 2), loss(1, 3)]).key, isNull);
      expect(rec([win(1, 1), win(1, 2), win(1, 3)]).key,
          'manager_hint.record.dominant');
      expect(rec([loss(1, 1), loss(1, 2), win(1, 3)]).key, isNull);
      expect(rec([loss(1, 1), loss(1, 2), loss(1, 3)]).key,
          'manager_hint.record.struggling');
    });

    test('and the SAMPLE SIZE is three meetings', () {
      // Two wins out of two is a run, not a record, and `streak.win.2` is
      // already the sentence for it.
      expect(rec([win(1, 1), win(1, 2)]).key, isNull);
      expect(rec([win(1, 1), win(1, 2)]).wins, 2);
    });

    test('a draw counts against neither side of the margin', () {
      // Three draws is a record of nothing, and it may not read as either.
      expect(rec([draw(1, 1), draw(1, 2), draw(1, 3)]).key, isNull);
      expect(rec([draw(1, 1), draw(1, 2), draw(1, 3)]).draws, 3);
    });

    test('an empty history is a record of nothing', () {
      final r = recordFor(const []);
      expect((r.key, r.wins, r.draws, r.losses), (null, 0, 0, 0));
    });
  });

  group('the pool the bubble picks from', () {
    ({List<String> keys, Map<String, Object?> params})? pool(
      List<({int season, int match, String opp, int ours, int theirs})> p,
    ) => fixtureHintPool(saveWith(p), 'Rivals', currentSeason: 3);

    test('IS THE FIXTURE\'S OWN LINE, and the record only JOINS it', () {
      // The JS concatenates rather than replacing, so a run of four still gets
      // to be the headline most of the times it exists. Four meetings with
      // Rivals is where the one-in-three roll lands on yes — pinned, because a
      // test that hopes for a roll is a test that fails one run in three.
      final p = pool([win(1, 1), win(1, 2), win(1, 3), win(1, 4)])!;
      expect(p.keys.first, 'manager_hint.streak.win.3plus');
      expect(p.keys, contains('manager_hint.record.dominant'));
    });

    test('and the roll can say no, with the same record in front of it', () {
      // Three meetings, same seed shape, and the record is dominant either
      // way — the only thing that changed is the roll.
      final p = pool([win(1, 1), win(1, 2), win(1, 3)])!;
      expect(p.keys, ['manager_hint.streak.win.3plus']);
      expect(recordFor(meetingsWith(saveWith([win(1, 1), win(1, 2), win(1, 3)]),
          'Rivals')).key, 'manager_hint.record.dominant');
    });

    test('an EVEN record never joins, however the roll falls', () {
      final p = pool([win(1, 1), win(1, 2), loss(1, 3), loss(1, 4)])!;
      expect(p.keys, hasLength(1));
    });

    test('THE COUNTS ARE ALWAYS THERE, key or no key', () {
      // The params a pooled key needs are the union across its variants, and a
      // caller that never prints a record pays nothing for carrying three ints.
      final p = pool([win(1, 1), loss(1, 2)])!;
      expect((p.params['wins'], p.params['draws'], p.params['losses']),
          (1, 0, 1));
    });

    test('a club we have never played gets no pool at all', () {
      expect(fixtureHintPool(saveWith([win(1, 1)]), 'Strangers',
          currentSeason: 3), isNull);
    });

    test('AND EVERY SENTENCE IN THE POOL RESOLVES, both keys\' worth', () {
      // The record variants ask for {wins}/{draws}/{losses} and the fixture's
      // own ask for {opp}/{n}/{lastScore}/{when} — one params map has to
      // satisfy all of them, because which sentence a player sees is a seed.
      // W W L W is a streak of one with a 3-1 record, so the pool is a last
      // meeting AND the record, which is the case that exercises both shapes.
      final p = pool([win(1, 1), win(1, 2), loss(1, 3), win(1, 4)])!;
      expect(p.keys, [
        'manager_hint.last_meeting.won',
        'manager_hint.record.dominant',
      ]);
      final when = p.params['when'];
      final params = {
        ...p.params,
        if (when is ManagerHint) 'when': t(when.key, when.params),
      };
      for (final key in p.keys) {
        for (final sentence in t(key, params).split('|')) {
          expect(sentence, isNot(contains('{')), reason: key);
          expect(sentence, isNot(contains('}')), reason: key);
        }
      }
    });
  });
}
