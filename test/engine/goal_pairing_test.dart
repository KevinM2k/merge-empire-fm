/// **OUR GOALS COME OFF OUR ATTACK AND THEIR DEFENCE**, and theirs off their
/// attack and our defence. Eleven call sites in `lib/` sample a goal count, and
/// each one has to pair the four numbers that way round.
///
/// Nothing else in the suite would notice if one of them did not. A
/// transposition — `(oppAttack, oppDefence)`, or our attack against our own
/// defence — still produces a plausible scoreline, still balances over a
/// season, and still hashes differently only in the difftest, which reports it
/// as "match 3 diverged" rather than as an inverted pairing. What the player
/// sees is a side that does not respond to being made better.
///
/// So the check here is a PARTIAL DERIVATIVE rather than an expected value:
/// raise one side's ATTACK and only that side's goals may move; raise its
/// DEFENCE and only the other side's may, and downward. All four hold together
/// for the correct pairing alone — a transposition, a self-pairing or a
/// wrong-side read breaks at least one of them, whatever it does to the totals.
///
/// Every sampler draws from the seeded stream, so these numbers are fixed
/// rather than approximate and the margins can be tight. The `closeTo`
/// tolerances are the sampling noise at the stated sample count, not slack.
///
/// **WHAT THIS PINS**: the four samplers directly, plus `simulateMatch` and
/// `prepareCupRound` end to end. The remaining call sites — the in-match
/// segmented path, `reSimulateRemainder`, the cup's injury windows and
/// `tactic_coach`'s forecast — are written the same way and are NOT pinned
/// here; they need a match in flight to reach.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/attack_sequence.dart';
import 'package:merge_empire_fc/engine/cup_engine.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/league_pyramid.dart';
import 'package:merge_empire_fc/engine/match_events.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart' show oppBaseAtkShare;
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/engine/match_resolution.dart';
import 'package:merge_empire_fc/engine/season_fixtures.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;
import 'package:merge_empire_fc/util/time.dart';

import '../support/js_math_random.dart';

final Map<String, dynamic> _questRef = jsonDecode(
  File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

/// Enough samples that the sampling noise is well inside the margins below, and
/// few enough that the whole file stays under a second.
const int _samples = 20000;

/// The size of the edge every case gives one side. Twenty rating points is far
/// past the noise and still inside the curve's responsive range.
const double _edge = 20;

/// Sampling noise at [_samples], for a stat that must NOT have moved.
const double _noise = 0.05;

/// Mean goals each way, over [_samples] runs of [play].
({double us, double them}) _mean(({int us, int them}) Function() play) {
  seeded.setSeed(99);
  var us = 0, them = 0;
  for (var i = 0; i < _samples; i++) {
    final r = play();
    us += r.us;
    them += r.them;
  }
  return (us: us / _samples, them: them / _samples);
}

/// The four partials, asserted together. [play] takes the two sides' ratings.
void _expectCrossPaired(
  ({int us, int them}) Function(
    double ourAtk,
    double ourDef,
    double oppAtk,
    double oppDef,
  )
  play, {
  double base = 50,
}) {
  final even = _mean(() => play(base, base, base, base));
  final ourAtkUp = _mean(() => play(base + _edge, base, base, base));
  final ourDefUp = _mean(() => play(base, base + _edge, base, base));
  final oppAtkUp = _mean(() => play(base, base, base + _edge, base));
  final oppDefUp = _mean(() => play(base, base, base, base + _edge));

  expect(
    ourAtkUp.us,
    greaterThan(even.us),
    reason: 'our attack must score us goals',
  );
  expect(
    ourAtkUp.them,
    closeTo(even.them, _noise),
    reason: 'our attack must not touch what we concede',
  );

  expect(
    ourDefUp.them,
    lessThan(even.them),
    reason: 'our defence must cut what we concede',
  );
  expect(
    ourDefUp.us,
    closeTo(even.us, _noise),
    reason: 'our defence must not touch what we score',
  );

  expect(
    oppAtkUp.them,
    greaterThan(even.them),
    reason: 'their attack must score them goals',
  );
  expect(
    oppAtkUp.us,
    closeTo(even.us, _noise),
    reason: 'their attack must not touch what we score',
  );

  expect(
    oppDefUp.us,
    lessThan(even.us),
    reason: 'their defence must cut what we score',
  );
  expect(
    oppDefUp.them,
    closeTo(even.them, _noise),
    reason: 'their defence must not touch what we concede',
  );
}

void main() {
  setUp(() => setClock(() => 1700000000000));
  tearDown(() {
    resetClock();
    resetMatchRandom();
    resetEventRandom();
    // `startCup` announces itself on the bus, and a listener left behind would
    // reach the next file.
    clearBus();
  });

  group('the goal rate', () {
    test('rises with the attacker and falls with the defender', () {
      // The root every sampler shares. Monotonicity in both arguments is what
      // makes the partials below meaningful rather than a coincidence of one
      // particular pair of ratings.
      //
      // STRICT only above [lambdaFloor]. The floor deliberately flattens the
      // curve for a hopeless underdog — at 50 the rate is pinned at 0.12 for
      // every attack under about 23 — so the strict test starts clear of it and
      // the floored region is asserted non-decreasing instead.
      for (var r = 30; r < 90; r += 10) {
        expect(
          goalRateLambda(r + 10, 50),
          greaterThan(goalRateLambda(r, 50)),
          reason: 'a better attack must mean more goals, at $r',
        );
      }
      for (var r = 5; r < 90; r += 5) {
        expect(
          goalRateLambda(r + 5, 50),
          greaterThanOrEqualTo(goalRateLambda(r, 50)),
          reason: 'a better attack can never mean fewer, at $r',
        );
        expect(
          goalRateLambda(50, r + 5),
          lessThanOrEqualTo(goalRateLambda(50, r)),
          reason: 'a better defence can never mean more, at $r',
        );
      }
      expect(
        goalRateLambda(50, 80),
        lessThan(goalRateLambda(50, 40)),
        reason: 'and off the floor it must be a real drop',
      );
    });
  });

  group('the samplers', () {
    test('resolveScoreline pairs each attack against the other defence', () {
      _expectCrossPaired(
        (oa, od, pa, pd) {
          final s = resolveScoreline((
            ourAttack: oa,
            ourDefence: od,
            oppAttack: pa,
            oppDefence: pd,
          ));
          return (us: s.home, them: s.away);
        },
      );
    });

    test('resolveSegmented pairs them the same way in every window', () {
      // The man-down path: two windows at the same ratings must behave like one
      // whole match, and each window has its own pair of samples to get wrong.
      _expectCrossPaired((oa, od, pa, pd) {
        final ratings = (
          ourAttack: oa,
          ourDefence: od,
          oppAttack: pa,
          oppDefence: pd,
        );
        final s = resolveSegmented([
          (upToMinute: 45, ratings: ratings),
          (upToMinute: 90, ratings: ratings),
        ]);
        return (us: s.home, them: s.away);
      });
    });

    test('simulateAiFixture pairs them for every AI row in every table', () {
      // This one fills the standings the player is judged against, so an
      // inverted pairing here would move promotion without touching a single
      // match the player watched.
      _expectCrossPaired(
        (ha, hd, aa, ad) {
          final r = simulateAiFixture(ha, hd, aa, ad);
          return (us: r.homeGoals, them: r.awayGoals);
        },
      );
    });

    test('the home club carries its advantage on both of its own numbers', () {
      // Not a pairing check but the same arithmetic: `homeDef + homeAdvantage`
      // reads oddly inside the away sampler and is the same bonus applied once
      // to each of the home club's two ratings — so an even fixture must favour
      // the hosts in BOTH directions.
      final even = _mean(() {
        final r = simulateAiFixture(50, 50, 50, 50);
        return (us: r.homeGoals, them: r.awayGoals);
      });
      expect(even.us, greaterThan(even.them));
    });

    test('the shootout pairs each side against the other', () {
      double winRate(num oa, num od, num pa, num pd) {
        seeded.setSeed(99);
        var wins = 0;
        for (var i = 0; i < _samples; i++) {
          if (simulatePenaltyShootout(oa, od, pa, pd).playerWins) wins++;
        }
        return wins / _samples;
      }

      final even = winRate(50, 50, 50, 50);
      expect(even, closeTo(0.5, 0.05), reason: 'an even shootout is a coin toss');
      expect(winRate(80, 50, 50, 50), greaterThan(even));
      expect(winRate(50, 50, 50, 80), lessThan(even));
    });
  });

  group('through a whole match', () {
    // **THE SAME CARDS AT THE SAME RATINGS, only the ATK/DEF share moved.**
    // `definitionRatios` is the save's own per-definition override, so this
    // changes the shape of the side and nothing else about it — no merges, no
    // substitutions, no change to who is on the pitch.
    //
    // The cross-pairing's signature is that BOTH goal counts move and in the
    // SAME direction: a side that pushes its weight forward scores more (its
    // attack is up) and concedes more (its defence is down). A self-paired sim
    // — our attack judged against our own defence — cannot produce that; it
    // moves one count, or moves them apart.
    Map<String, dynamic> stateAt(double outfieldShare) {
      final s = jsonDecode(jsonEncode(_questRef['state']))
          as Map<String, dynamic>;
      final prog = s['progression'] as Map<String, dynamic>;
      prog['currentDivision'] = 'regional_league';
      prog['seasonCount'] = 1;
      prog['seasonMatchesPlayed'] = 0;
      prog['seasonAwardedPlayed'] = 0;
      prog['leaguePyramid'] = null;
      prog['seasonOpponents'] = <dynamic>[];
      prog['seasonOpponentRatings'] = <String, dynamic>{};
      prog['seasonFixtures'] = null;
      prog['stagnationBuffs'] = <String, dynamic>{};
      prog['cups'] = <String, dynamic>{
        'active': null,
        'history': <dynamic>[],
        'availableThisSeason': true,
      };

      // The keeper is left alone: his share is zero at every tier and shifting
      // it would change the side's DEF for a reason that has nothing to do with
      // the shape under test.
      final ratios = <String, dynamic>{};
      for (final raw in (s['grid'] as Map<String, dynamic>)['cells'] as List) {
        if (raw is! Map) continue;
        final id = '${raw['definitionId']}';
        if (id.endsWith('_gk')) continue;
        ratios[id] = outfieldShare;
      }
      s['definitionRatios'] = ratios;

      ensureLeaguePyramid(s);
      // One rating for every club in the division, so the only thing that
      // differs between the two runs is our own shape.
      for (final t
          in ((prog['leaguePyramid'] as Map)['regional_league']) as List) {
        (t as Map<String, dynamic>)['rating'] = 38;
      }
      initSeasonOpponents(s);
      final seeds = prog['seasonOpponentRatings'] as Map<String, dynamic>;
      for (var i = 0; i < 7; i++) {
        seeds['s1_o$i'] = 38;
      }
      prog['seasonFixtures'] = null;
      generateSeasonFixtures(s);
      return s;
    }

    /// Goals each way over [runs] fixtures, each on a FRESH save — an injury
    /// leaves a hole that the match screen fills at full time, and reusing one
    /// save here would measure that instead of the shape.
    ({double us, double them}) playAt(double share, int runs) {
      var us = 0, them = 0;
      for (var i = 0; i < runs; i++) {
        seeded.setSeed(4000 + i);
        final unseeded = JsMathRandom(8000 + i);
        setMatchRandom(unseeded);
        setEventRandom(unseeded);
        final result = simulateMatch(stateAt(share), 'regional_league');
        us += (result['homeGoals'] as num).toInt();
        them += (result['awayGoals'] as num).toInt();
      }
      return (us: us / runs, them: them / runs);
    }

    test('simulateMatch moves both scores when our shape moves', () {
      const runs = 400;
      final attacking = playAt(0.90, runs);
      final defensive = playAt(0.10, runs);
      expect(
        attacking.us,
        greaterThan(defensive.us + 0.2),
        reason: 'weight forward must score us more',
      );
      expect(
        attacking.them,
        greaterThan(defensive.them + 0.2),
        reason: 'and must cost us at the back — the other half of the pairing',
      );
    });

    test('prepareCupRound pairs a cup tie the same way', () {
      // A cup tie is played on neutral ground by a different function, so it is
      // its own pair of samples to get wrong.
      //
      // **The bracket is pinned first.** Left alone, a cup opponent with no
      // stored rating is drawn at `squadRating + bump`, so moving our shape
      // moves the badge it is scaled off and the tie re-rates itself out from
      // under the test. Writing a rating onto `opponentMeta` is the path
      // `prepareCupRound` takes for a club actually drawn out of the pyramid.
      ({double us, double them}) cupAt(double share) {
        const runs = 300;
        var us = 0, them = 0, played = 0;
        for (var i = 0; i < runs; i++) {
          seeded.setSeed(4000 + i);
          final state = stateAt(share);
          if (startCup(state) == null) continue;
          final run = ((state['progression'] as Map)['cups']
              as Map<String, dynamic>)['active'] as Map<String, dynamic>;
          for (final raw in run['opponentMeta'] as List) {
            (raw as Map<String, dynamic>)
              ..['rating'] = 38
              ..['attackRatio'] = oppBaseAtkShare;
          }
          final prepared = prepareCupRound(state);
          if (prepared == null) continue;
          us += prepared.homeGoals;
          them += prepared.awayGoals;
          played++;
        }
        expect(played, greaterThan(runs ~/ 2), reason: 'the cup has to be on');
        return (us: us / played, them: them / played);
      }

      final attacking = cupAt(0.90);
      final defensive = cupAt(0.10);
      expect(
        attacking.us,
        greaterThan(defensive.us + 0.2),
        reason: 'weight forward must score us more in a cup tie too',
      );
      expect(
        attacking.them,
        greaterThan(defensive.them + 0.2),
        reason: 'and must cost us at the back',
      );
    });
  });

  group('the positional duel is our ATK against their DEF', () {
    // The samplers above prove the λ each side is handed is paired the right
    // way round. The sequence underneath has its own pairing — the carrier's
    // ATTACK against the defender's DEFENCE — and the same partial derivative
    // pins it: raise OUR attack and only OUR shots rise; raise THEIR defence
    // and only OUR shots fall. Their shots are their λ's business.
    int shotsFor(String side, {double ourAtk = 70, double theirDef = 70}) {
      seeded.setSeed(4242);
      final us = pitchSideForAi(70, '4-3-3', mirrored: false)
          .scaledToTeam(attack: ourAtk, defence: 70);
      final them = pitchSideForAi(70, '4-4-2')
          .scaledToTeam(attack: 70, defence: theirDef);
      final out = <PositionalEvent>[];
      for (var i = 0; i < 600; i++) {
        positionalWindowGoals(
          ctx: side == 'ours'
              ? SequenceContext(attackers: us, defenders: them, side: 'ours')
              : SequenceContext(attackers: them, defenders: us, side: 'theirs'),
          lambda: 1.35,
          fromMinute: 0,
          toMinute: 90,
          out: out,
        );
      }
      return out.where((e) => e.type == 'shot' && e.outcome != 'blocked').length;
    }

    test('raising our attack raises our shots and not theirs', () {
      final base = shotsFor('ours');
      expect(shotsFor('ours', ourAtk: 90), greaterThan(base * 1.15));
      // Their attack against our unchanged defence: same draws, same shots.
      expect(shotsFor('theirs', ourAtk: 90), shotsFor('theirs'));
    });

    test('raising their defence lowers our shots and not theirs', () {
      final base = shotsFor('ours');
      expect(shotsFor('ours', theirDef: 90), lessThan(base * 0.85));
      expect(shotsFor('theirs', theirDef: 90), shotsFor('theirs'));
    });
  });
}
