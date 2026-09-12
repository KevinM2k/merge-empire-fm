/// **THE TEAMS TAKE IT IN TURNS.**
///
/// A cup tie that finishes level is settled from the spot, and the shootout is
/// simulated kick by kick so the summary can show how it went — see
/// `ShootoutRow`. What no test asked was whether that list is a shootout: that
/// it alternates, that the running totals under it add up, that neither side
/// gets an extra go, and that the side with the most penalties is the side the
/// tie is awarded to.
///
/// Every one of those is a way for the kicks on screen to disagree with the
/// result beside them, which is what "the score is messed up" looks like from
/// the couch. `goal_pairing_test` already pins that a BETTER side wins more
/// shootouts; this is the shape of one.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

void main() {
  /// Every shape of mismatch, so a rule that only holds for evenly matched
  /// sides cannot pass.
  const sides = <(num, num, num, num)>[
    (50, 50, 50, 50),
    (90, 30, 30, 90),
    (30, 90, 90, 30),
    (1, 1, 1, 1),
    (0, 0, 0, 0),
  ];

  test('HOME, AWAY, HOME, AWAY — nobody kicks twice in a row', () {
    for (final (oa, od, pa, pd) in sides) {
      for (var seed = 0; seed < 60; seed++) {
        seeded.setSeed(seed);
        final kicks = simulatePenaltyShootout(oa, od, pa, pd).kicks;
        expect(kicks, isNotEmpty);
        for (var i = 0; i < kicks.length; i++) {
          expect(
            kicks[i].team,
            i.isEven ? 'home' : 'away',
            reason: 'seed $seed: kick $i is out of turn',
          );
        }
      }
    }
  });

  test('and the away side always gets its answer', () {
    // The regulation five can stop early — that is what "out of reach" means,
    // and it is the home side's kick that can end it. Sudden death cannot:
    // breaking on a home goal there would hand the tie over without the away
    // team taking theirs.
    for (final (oa, od, pa, pd) in sides) {
      for (var seed = 0; seed < 60; seed++) {
        seeded.setSeed(seed);
        final kicks = simulatePenaltyShootout(oa, od, pa, pd).kicks;
        final sudden = kicks.where((k) => k.suddenDeath).toList();
        expect(
          sudden.length.isEven,
          isTrue,
          reason: 'seed $seed: sudden death ended on a half-finished round',
        );
        // Neither side may take more than one kick more than the other, and
        // only the home side can be the one ahead.
        final home = kicks.where((k) => k.team == 'home').length;
        final away = kicks.where((k) => k.team == 'away').length;
        expect(home - away, anyOf(0, 1), reason: 'seed $seed: $home v $away');
      }
    }
  });

  test('the running totals under the marks are the totals', () {
    for (final (oa, od, pa, pd) in sides) {
      for (var seed = 0; seed < 60; seed++) {
        seeded.setSeed(seed);
        final out = simulatePenaltyShootout(oa, od, pa, pd);
        var home = 0;
        var away = 0;
        for (final kick in out.kicks) {
          if (kick.scored) {
            if (kick.team == 'home') {
              home++;
            } else {
              away++;
            }
          }
          expect(kick.homeTotal, home, reason: 'seed $seed');
          expect(kick.awayTotal, away, reason: 'seed $seed');
        }
        expect(out.homeScore, home, reason: 'seed $seed');
        expect(out.awayScore, away, reason: 'seed $seed');
      }
    }
  });

  test('WHOEVER WINS THE PENALTIES WINS THE TIE, and it cannot end level', () {
    for (final (oa, od, pa, pd) in sides) {
      for (var seed = 0; seed < 60; seed++) {
        seeded.setSeed(seed);
        final out = simulatePenaltyShootout(oa, od, pa, pd);
        expect(
          out.homeScore,
          isNot(out.awayScore),
          reason: 'seed $seed: a shootout that settled nothing',
        );
        expect(
          out.playerWins,
          out.homeScore > out.awayScore,
          reason: 'seed $seed: the tie went to the side with fewer penalties',
        );
      }
    }
  });

  test('and a zeroed rating cannot loop for ever', () {
    // Every input is floored at one for exactly this: sudden death runs until
    // one side is ahead, and a probability of zero on both sides never is.
    seeded.setSeed(7);
    final out = simulatePenaltyShootout(0, 0, 0, 0);
    expect(out.kicks.length, lessThan(200));
  });
}
