/// Is the positional sim RIGHT — not merely unchanged.
///
/// The goldens pin whatever they were handed. This suite is the half of the
/// net that asks the questions a golden structurally cannot: over ~20k
/// simulated matches, does the calibration bridge conserve λ, does the game
/// still produce football's numbers, does rating still decide matches, is the
/// all-out-attack exploit still dead, and is the feature actually doing its
/// job — a better winger winning more duels and taking more of his side's
/// shots down his flank.
///
/// Tolerances are sampling noise at the stated counts, not slack. Every
/// sampler draws from the seeded stream, so a run is reproducible.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/attack_sequence.dart';
import 'package:merge_empire_fc/engine/goal_model.dart';
import 'package:merge_empire_fc/engine/match_analysis.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

/// Eleven at [rating] in [shape], as the sim builds an AI side; `mirrored`
/// false is our end of the pitch.
PitchSide _side(num rating, String shape, {bool ours = false}) =>
    pitchSideForAi(rating, shape, mirrored: !ours);

typedef _Tally = ({
  int matches,
  int homeGoals,
  int awayGoals,
  int draws,
  int homeWins,
  int shots,
  double xg,
});

/// [n] matches between two sides at the given team ATK/DEF pairs, through the
/// positional sim exactly as `simulateMatch` drives it.
_Tally _play({
  required PitchSide ours,
  required PitchSide theirs,
  required double ourAtk,
  required double ourDef,
  required double oppAtk,
  required double oppDef,
  int n = 2000,
  double variance = 1,
}) {
  final us = ours.scaledToTeam(attack: ourAtk, defence: ourDef);
  final them = theirs.scaledToTeam(attack: oppAtk, defence: oppDef);
  var h = 0, a = 0, draws = 0, wins = 0, shots = 0;
  var xg = 0.0;
  for (var i = 0; i < n; i++) {
    final out = <PositionalEvent>[];
    final hg = positionalWindowGoals(
      ctx: SequenceContext(attackers: us, defenders: them, side: 'ours'),
      lambda: goalRateLambda(ourAtk, oppDef) * variance,
      fromMinute: 0,
      toMinute: 90,
      out: out,
    );
    final ag = positionalWindowGoals(
      ctx: SequenceContext(attackers: them, defenders: us, side: 'theirs'),
      lambda: goalRateLambda(oppAtk, ourDef) * variance,
      fromMinute: 0,
      toMinute: 90,
      out: out,
    );
    h += hg;
    a += ag;
    if (hg == ag) draws++;
    if (hg > ag) wins++;
    for (final e in out) {
      if (e.type == 'shot' && e.outcome != 'blocked') {
        shots++;
        xg += e.xg ?? 0;
      }
    }
  }
  return (
    matches: n,
    homeGoals: h,
    awayGoals: a,
    draws: draws,
    homeWins: wins,
    shots: shots,
    xg: xg,
  );
}

double _points(_Tally t) => (3 * t.homeWins + t.draws) / t.matches;

/// P(draw) for two independent Poissons.
double _poissonDraw(double l1, double l2) {
  var p = 0.0;
  var f = 1.0;
  for (var k = 0; k < 12; k++) {
    if (k > 0) f *= k;
    p += math.exp(-l1 - l2) * math.pow(l1 * l2, k) / (f * f);
  }
  return p;
}

CardInstance _card(String id, String pos, int tier) => CardInstance({
  'instanceId': id,
  'definitionId': 'player_t${tier}_${pos.toLowerCase()}',
});

/// Our 4-3-3 from real cards, every slot at [tier] except the overrides.
PitchSide _lineupSide({
  int tier = 5,
  Map<String, int> tiers = const {},
  Map<String, String> roles = const {},
}) {
  final slots = formations['4-3-3']!.slots;
  final cards = [
    for (final s in slots)
      _card(s.slotId, s.slotPosition, tiers[s.slotId] ?? tier),
  ];
  final lineup = [
    for (final s in slots)
      {
        'slotId': s.slotId,
        'slotPosition': s.slotPosition,
        'cardInstanceId': s.slotId,
      },
  ];
  return pitchSideFromLineup(
    cards: cards,
    lineup: lineup,
    slots: slots,
    roles: roles,
  );
}

void main() {
  setUp(() => seeded.setSeed(20260912));

  group('λ conservation', () {
    test('every shot list sums to its window lambda exactly, jitter off', () {
      final ours = _side(70, '4-3-3', ours: true);
      final theirs = _side(70, '4-4-2');
      for (var i = 0; i < 500; i++) {
        final lambda = 0.4 + (i % 7) * 0.35;
        final out = <PositionalEvent>[];
        positionalWindowGoals(
          ctx: SequenceContext(
            attackers: ours,
            defenders: theirs,
            side: 'ours',
          ),
          lambda: lambda,
          fromMinute: 0,
          toMinute: 90,
          out: out,
          jitter: 0,
        );
        final shots = out
            .where((e) => e.type == 'shot' && e.outcome != 'blocked')
            .toList();
        if (shots.isEmpty || shots.any((e) => e.xg! >= shotCap)) continue;
        expect(
          shots.fold(0.0, (a, e) => a + e.xg!),
          closeTo(lambda, 1e-9),
          reason: 'match $i, lambda $lambda',
        );
      }
    });

    test(
      'expected goals per side equal goalRateLambda across the rating range',
      () {
        for (final (us, them) in [(70, 70), (82, 58), (55, 80), (92, 48)]) {
          final t = _play(
            ours: _side(us, '4-3-3', ours: true),
            theirs: _side(them, '4-4-2'),
            ourAtk: us.toDouble(),
            ourDef: us.toDouble(),
            oppAtk: them.toDouble(),
            oppDef: them.toDouble(),
            n: 3000,
          );
          final lh = goalRateLambda(us, them);
          final la = goalRateLambda(them, us);
          // Standard error ≈ sqrt(λ/n) ≈ 0.02–0.03.
          expect(
            t.homeGoals / t.matches,
            closeTo(lh, 0.09),
            reason: '$us v $them home',
          );
          expect(
            t.awayGoals / t.matches,
            closeTo(la, 0.09),
            reason: '$us v $them away',
          );
        }
      },
    );
  });

  group("football's numbers at parity", () {
    // Two like-for-like sides at 70, their ATK/DEF the real position-weighted
    // splits — not a literal 70/70, which the goal model's even-match anchor
    // (`evenAttackProb`) was never set at. The totals are the GOAL MODEL's and
    // this layer may not move them; what it may move is how they are spread.
    late TeamSplit split;
    late double lambda;
    late _Tally even;
    setUpAll(() {
      seeded.setSeed(7);
      split = teamSplitForFormation(70, '4-3-3');
      lambda = goalRateLambda(split.attack, split.defence);
      even = _play(
        ours: _side(70, '4-3-3', ours: true),
        theirs: _side(70, '4-3-3'),
        ourAtk: split.attack.toDouble(),
        ourDef: split.defence.toDouble(),
        oppAtk: split.attack.toDouble(),
        oppDef: split.defence.toDouble(),
        n: 10000,
      );
    });

    test('goals a match are the goal model\'s — about 2.6 for two 4-3-3s', () {
      expect(2 * lambda, inInclusiveRange(2.5, 2.8));
      // Standard error on the total is about 0.016 at this count.
      expect(
        (even.homeGoals + even.awayGoals) / even.matches,
        closeTo(2 * lambda, 0.06),
      );
    });

    test(
      'a quarter of matches drawn — the Poisson\'s rate, not the Poisson-binomial\'s',
      () {
        final poisson = _poissonDraw(lambda, lambda);
        expect(poisson, inInclusiveRange(0.24, 0.29));
        final drawn = even.draws / even.matches;
        // The under-dispersion `calibrationJitter` exists to remove: within 1.5
        // points of the Poisson's own draw rate. Standard error here is 0.0044.
        expect(
          (drawn - poisson).abs(),
          lessThan(0.015),
          reason: '$drawn v $poisson',
        );
      },
    );

    test('about thirteen shots a match — the feed\'s figure, preserved', () {
      expect(even.shots / even.matches, inInclusiveRange(11.5, 14.5));
    });

    test('the summed xG is the goals', () {
      expect(
        even.xg / even.matches,
        closeTo((even.homeGoals + even.awayGoals) / even.matches, 0.1),
      );
    });
  });

  group('rating decides matches', () {
    test('win probability rises monotonically with the rating gap', () {
      final rates = <double>[];
      for (final gap in [-20, -10, -5, 0, 5, 10, 20]) {
        final us = 70 + gap / 2;
        final them = 70 - gap / 2;
        final t = _play(
          ours: _side(us, '4-4-2', ours: true),
          theirs: _side(them, '4-4-2'),
          ourAtk: us,
          ourDef: us,
          oppAtk: them,
          oppDef: them,
          n: 2500,
        );
        rates.add(t.homeWins / t.matches);
      }
      for (var i = 1; i < rates.length; i++) {
        expect(
          rates[i],
          greaterThan(rates[i - 1]),
          reason: 'gap step $i: $rates',
        );
      }
      expect(rates.first, lessThan(0.2));
      expect(rates.last, greaterThan(0.65));
    });
  });

  group('tactics through this layer are the goal model\'s, no more', () {
    // Whether a tactic pays is the goal model's question — `lambdaCurveExp`
    // was set to 1.0 to stop a weak side manufacturing wins by attacking, and
    // whatever it now says, it says through λ alone. This layer conserves λ,
    // so the expected points a tactic earns here must equal what two plain
    // Poissons at the same λ would earn, to within sampling noise. If they
    // ever part company, the exploit has found a second door.
    ({double positional, double poisson}) points(
      String tactic, {
      required double us,
      required double them,
    }) {
      seeded.setSeed(99);
      final strat = strategies[tactic]!;
      final m = tacticMultipliers(strat, positionAttackRatio['MID']);
      final atk = us * m.atk;
      final def = us * m.def;
      final t = _play(
        ours: _side(us, '4-3-3', ours: true),
        theirs: _side(them, '4-4-2'),
        ourAtk: atk,
        ourDef: def,
        oppAtk: them,
        oppDef: them,
        n: 6000,
        variance: strat.variance,
      );
      final lf = goalRateLambda(atk, them) * strat.variance;
      final la = goalRateLambda(them, def) * strat.variance;
      final pf = poissonPmf(lf);
      final pa = poissonPmf(la);
      var win = 0.0, draw = 0.0;
      for (var h = 0; h < pf.length; h++) {
        for (var a = 0; a < pa.length; a++) {
          if (h > a) win += pf[h] * pa[a];
          if (h == a) draw += pf[h] * pa[a];
        }
      }
      return (positional: _points(t), poisson: 3 * win + draw);
    }

    for (final (us, them) in [(56.0, 74.0), (70.0, 70.0), (78.0, 60.0)]) {
      test('each tactic earns what the Poisson earns — $us v $them', () {
        for (final tactic in [
          'balanced',
          'allOutAttack',
          'parkTheBus',
          'highPress',
        ]) {
          final p = points(tactic, us: us, them: them);
          // Standard error on points at 6000 matches is about 0.016.
          expect(p.positional, closeTo(p.poisson, 0.05), reason: '$tactic $p');
        }
      });
    }

    test('at parity, attacking buys goals both ways and no points', () {
      final balanced = points('balanced', us: 70, them: 70);
      final attack = points('allOutAttack', us: 70, them: 70);
      expect(attack.poisson, closeTo(balanced.poisson, 0.06));
      expect(attack.positional, closeTo(balanced.positional, 0.06));
    });
  });

  group('the feature does its job', () {
    late Map<String, dynamic> plain;
    late Map<String, dynamic> star;
    late PitchSide plainSide;
    late PitchSide starSide;

    /// A season and a half against a 62-rated 4-4-2. In `simulateMatch` the
    /// team figures a side is scaled to come from the same eleven, so a better
    /// winger IS a better team; the λ here follows each side's own means the
    /// same way rather than pinning both squads to one number.
    Map<String, dynamic> season(PitchSide us) {
      final them = _side(62, '4-4-2');
      final ours = us.teamMeans;
      final theirs = them.teamMeans;
      final out = <PositionalEvent>[];
      for (var i = 0; i < 1500; i++) {
        positionalWindowGoals(
          ctx: SequenceContext(attackers: us, defenders: them, side: 'ours'),
          lambda: goalRateLambda(ours.attack, theirs.defence),
          fromMinute: 0,
          toMinute: 90,
          out: out,
        );
        positionalWindowGoals(
          ctx: SequenceContext(attackers: them, defenders: us, side: 'theirs'),
          lambda: goalRateLambda(theirs.attack, ours.defence),
          fromMinute: 0,
          toMinute: 90,
          out: out,
        );
      }
      return positionalSummary(out);
    }

    setUpAll(() {
      seeded.setSeed(5);
      plainSide = _lineupSide();
      starSide = _lineupSide(tiers: {'rf': 9});
      plain = season(plainSide);
      seeded.setSeed(5);
      star = season(starSide);
    });

    double winRate(Map<String, dynamic> s, String id) {
      final d = (s['duels'] as Map)[id] as Map;
      final w = d['w'] as int;
      final l = d['l'] as int;
      return w / (w + l);
    }

    double shotShare(Map<String, dynamic> s, String id) {
      final line = (s['shooters'] as Map)[id] as Map?;
      final shots = (line?['shots'] as int?) ?? 0;
      return shots / ((s['shots'] as Map)['ours'] as int);
    }

    test('the star winger is a materially better player', () {
      final a = starSide.players.firstWhere((p) => p.slotId == 'rf').attack;
      final b = plainSide.players.firstWhere((p) => p.slotId == 'rf').attack;
      expect(a, greaterThan(85));
      expect(b, lessThan(70));
      // And the full-back he meets is the 55-ish the brief describes.
      final lb = _side(62, '4-4-2').players.firstWhere((p) => p.slotId == 'lb');
      expect(lb.defence, inInclusiveRange(50, 75));
    });

    test('he wins materially more of his duels', () {
      expect(winRate(star, 'rf'), greaterThan(winRate(plain, 'rf') + 0.12));
    });

    test('he takes a materially larger share of his side\'s shots', () {
      expect(shotShare(star, 'rf'), greaterThan(shotShare(plain, 'rf') + 0.06));
    });

    test('and his side\'s attacks shift toward his flank', () {
      final before = flankShares(plain, 'ours')[Flank.right]!;
      final after = flankShares(star, 'ours')[Flank.right]!;
      // About three points for a t9 winger in a t5 side; sampling noise on a
      // share of ~8,000 shots is 0.0055, so this is three sigma of it.
      expect(
        after,
        greaterThan(before + 0.015),
        reason: '${plain['flank']} -> ${star['flank']}',
      );
    });

    test('the opposition\'s flanks do not move because ours did', () {
      // Their side is identical in both seasons and attacks our unchanged
      // defence; where THEY come down the pitch is theirs to decide.
      final a = flankShares(plain, 'theirs');
      final b = flankShares(star, 'theirs');
      for (final f in Flank.values) {
        expect(b[f], closeTo(a[f]!, 0.03), reason: '$f');
      }
    });

    test('the duel is our ATK against their DEF, pinned at the sequence', () {
      // Raise their DEFENCE and only their duel wins may rise; our shots fall.
      seeded.setSeed(8);
      Map<String, dynamic> run(double theirDef) {
        final us = _side(
          70,
          '4-3-3',
          ours: true,
        ).scaledToTeam(attack: 70, defence: 70);
        final them = _side(
          70,
          '4-4-2',
        ).scaledToTeam(attack: 70, defence: theirDef);
        final out = <PositionalEvent>[];
        for (var i = 0; i < 800; i++) {
          positionalWindowGoals(
            ctx: SequenceContext(attackers: us, defenders: them, side: 'ours'),
            lambda: 1.35,
            fromMinute: 0,
            toMinute: 90,
            out: out,
          );
        }
        return positionalSummary(out);
      }

      final soft = run(55);
      final hard = run(90);
      expect(
        (hard['shots'] as Map)['ours'],
        lessThan(((soft['shots'] as Map)['ours'] as int) * 0.8),
      );
    });
  });

  group('the side dial', () {
    ({double right, double goals}) season(String side) {
      seeded.setSeed(21);
      final us = _side(70, '4-3-3', ours: true);
      final them = _side(70, '4-4-2');
      final out = <PositionalEvent>[];
      var goals = 0;
      for (var i = 0; i < 2000; i++) {
        goals += positionalWindowGoals(
          ctx: SequenceContext(
            attackers: us,
            defenders: them,
            side: 'ours',
            laneBias: laneBiasFor(side),
          ),
          lambda: 1.35,
          fromMinute: 0,
          toMinute: 90,
          out: out,
        );
      }
      final sum = positionalSummary(out);
      return (right: flankShares(sum, 'ours')[Flank.right]!, goals: goals / 2000);
    }

    test('a committed side moves the flank share materially', () {
      final balanced = season('balanced');
      final right = season('right');
      final left = season('left');
      expect(right.right, greaterThan(balanced.right + 0.08));
      expect(left.right, lessThan(balanced.right - 0.08));
    });

    test('and moves the goals not at all', () {
      // Expected goals are λ whatever the dial says; 0.06 is three standard
      // errors at this count.
      for (final side in attackSides) {
        expect(season(side).goals, closeTo(1.35, 0.06), reason: side);
      }
    });
  });

  group('roles', () {
    test('an inside forward takes more of his shots from the middle', () {
      double centreShare(Map<String, String> roles) {
        seeded.setSeed(31);
        final us = _lineupSide(roles: roles);
        final them = _side(64, '4-4-2');
        final out = <PositionalEvent>[];
        for (var i = 0; i < 2000; i++) {
          positionalWindowGoals(
            ctx: SequenceContext(attackers: us, defenders: them, side: 'ours'),
            lambda: 1.4,
            fromMinute: 0,
            toMinute: 90,
            out: out,
          );
        }
        var centre = 0, total = 0;
        for (final e in out) {
          if (e.type != 'shot' || e.playerId != 'rf') continue;
          total++;
          if (zoneLane(e.zone) == 2) centre++;
        }
        return centre / total;
      }
      final natural = centreShare(const {});
      final inside = centreShare(const {'rf': 'insideForward'});
      final winger = centreShare(const {'rf': 'winger'});
      expect(inside, greaterThan(natural + 0.05));
      expect(winger, lessThanOrEqualTo(natural + 0.01));
    });
  });

  group('defensive support', () {
    double shotsAgainst(String theirShape) {
      seeded.setSeed(41);
      final ours = _side(70, '4-3-3', ours: true);
      final theirs = _side(70, theirShape);
      var shots = 0;
      const n = 3000;
      for (var i = 0; i < n; i++) {
        final out = <PositionalEvent>[];
        positionalWindowGoals(
          ctx: SequenceContext(attackers: ours, defenders: theirs, side: 'ours'),
          lambda: 1.35,
          fromMinute: 0,
          toMinute: 90,
          out: out,
        );
        shots += out.where((e) => e.type == 'shot' && e.outcome != 'blocked').length;
      }
      return shots / n;
    }

    test('a packed defence concedes fewer shots on the same lambda', () {
      final block = shotsAgainst('5-4-1');
      final open = shotsAgainst('3-4-3');
      expect(block, lessThan(open * 0.96));
    });

    test('and the same goals', () {
      // λ conservation is the guarantee; this is it seen from the other end.
      seeded.setSeed(42);
      final ours = _side(70, '4-3-3', ours: true);
      var goals = 0;
      const n = 4000;
      for (var i = 0; i < n; i++) {
        goals += positionalWindowGoals(
          ctx: SequenceContext(attackers: ours, defenders: _side(70, '5-4-1'), side: 'ours'),
          lambda: 1.35,
          fromMinute: 0,
          toMinute: 90,
          out: <PositionalEvent>[],
        );
      }
      expect(goals / n, closeTo(1.35, 0.06));
    });
  });
}
