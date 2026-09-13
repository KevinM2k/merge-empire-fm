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

/// Our eleven from real cards, every slot at [tier] except the overrides.
PitchSide _lineupSide({
  String shape = '4-3-3',
  int tier = 5,
  Map<String, int> tiers = const {},
  Map<String, String> roles = const {},
}) {
  final slots = formations[shape]!.slots;
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

  /// The brief's own test, and the one claim the whole feature rests on: with
  /// the SAME eleven and the SAME lambda, which flank you attack has to matter,
  /// because the defender waiting there is a different man.
  ///
  /// Their back four is lopsided on purpose — a 50 left-back, 75 centre-backs,
  /// an 85 right-back — and their `lb` is mirrored onto OUR RIGHT, so our right
  /// is the soft side. Our two wingers are the same 95-ATK player, which is what
  /// makes the gap between them attributable to the opposition and nothing else.
  group('a weak flank is the side to attack', () {
    /// An AI 4-4-2 with that back four. Everyone else is left exactly as
    /// `pitchSideForAi` built him, maps included — only four DEF numbers move.
    PitchSide lopsided() {
      const defence = {'lb': 50.0, 'lcb': 75.0, 'rcb': 75.0, 'rb': 85.0};
      return PitchSide([
        for (final p in _side(70, '4-4-2').players)
          if (defence.containsKey(p.slotId))
            PitchPlayer(
              id: p.id,
              slotId: p.slotId,
              slotPosition: p.slotPosition,
              name: p.name,
              attack: p.attack,
              defence: defence[p.slotId]!,
              attacking: p.attacking,
              defending: p.defending,
            )
          else
            p,
      ]);
    }

    final us = _lineupSide(tiers: {'rf': 8, 'lf': 8});
    final them = lopsided();
    final lambda = goalRateLambda(us.teamMeans.attack, them.teamMeans.defence);

    /// 3,000 matches of our attacks at [side], lambda from the two sides' own
    /// means so the goal model is handed what `simulateMatch` would hand it.
    ({Map<String, dynamic> sum, double goals, int duels, double duelWin}) season(
      String side,
    ) {
      seeded.setSeed(404);
      final out = <PositionalEvent>[];
      var goals = 0;
      const n = 3000;
      for (var i = 0; i < n; i++) {
        goals += positionalWindowGoals(
          ctx: SequenceContext(
            attackers: us,
            defenders: them,
            side: 'ours',
            laneBias: laneBiasFor(side),
          ),
          lambda: lambda,
          fromMinute: 0,
          toMinute: 90,
          out: out,
        );
      }
      final sum = positionalSummary(out);
      var w = 0, l = 0;
      for (final p in us.players) {
        final d = (sum['duels'] as Map)[p.id] as Map?;
        if (d == null) continue;
        w += d['w'] as int;
        l += d['l'] as int;
      }
      return (
        sum: sum,
        goals: goals / n,
        duels: w + l,
        duelWin: w / (w + l),
      );
    }

    double wingerWin(Map<String, dynamic> s, String slotId) {
      final d = (s['duels'] as Map)[slotId] as Map;
      return (d['w'] as int) / ((d['w'] as int) + (d['l'] as int));
    }

    test('the two wingers are the same player and the flanks are not', () {
      final rf = us.players.firstWhere((p) => p.slotId == 'rf');
      final lf = us.players.firstWhere((p) => p.slotId == 'lf');
      expect(rf.attack, lf.attack);
      expect(rf.attack, greaterThan(90));
      // Their left-back — the one our `rf` meets — against their right-back.
      expect(them.players.firstWhere((p) => p.slotId == 'lb').defence, 50);
      expect(them.players.firstWhere((p) => p.slotId == 'rb').defence, 85);
    });

    test('the winger facing the 50 wins materially more than the one facing '
        'the 85', () {
      final s = season('balanced').sum;
      final right = wingerWin(s, 'rf');
      final left = wingerWin(s, 'lf');
      // Measured 0.654 against 0.559 over ~7,200 and ~5,700 duels; the gap's
      // own sampling error is 0.0086, so 0.06 is four sigma inside it.
      expect(
        right,
        greaterThan(left + 0.06),
        reason: 'rf $right vs lf $left',
      );
    });

    test('committing to the weak side wins more of the duels', () {
      final right = season('right');
      final left = season('left');
      // 0.200 against 0.176 over ~134,000 duels, where a sigma is 0.0011.
      expect(
        right.duelWin,
        greaterThan(left.duelWin + 0.012),
        reason: '${right.duelWin} vs ${left.duelWin}',
      );
    });

    test('and gets materially more shots away', () {
      final right = (season('right').sum['shots'] as Map)['ours'] as int;
      final left = (season('left').sum['shots'] as Map)['ours'] as int;
      // 8,623 against 6,910 — a quarter more, on one unchanged lambda.
      expect(right, greaterThan((left * 1.15).round()), reason: '$right/$left');
    });

    test('and scores exactly the goals the goal model said, either way', () {
      // THE point of the calibration bridge: picking the soft flank changes
      // where the match is played and how much of it your winger sees, and it
      // cannot change how many goals a side of this quality scores against a
      // defence of that quality. 0.055 is three standard errors at 3,000
      // matches.
      for (final side in attackSides) {
        expect(season(side).goals, closeTo(lambda, 0.055), reason: side);
      }
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

  // -------------------------------------------------------------------------
  // DOES A SHAPE BEHAVE LIKE THE SHAPE IT IS?
  //
  // The one thing a golden structurally cannot ask, and the thing the whole
  // positional layer is FOR: change nothing but where the eleven stand — same
  // ratings, same lambda, same opponent — and the match should be played
  // somewhere else. If a 4-3-3 and a 4-2-3-1 produce the same map, the
  // coordinates are decoration.
  // -------------------------------------------------------------------------

  group('a shape is played where it stands', () {
    test('every slot in every shape works the flank its own x implies', () {
      // No sampling at all: this is the influence map read straight off the
      // formation. Lanes are 20 wide and the outer two either side are the
      // flanks, so x under 40 is the team's own right and 60 or over its left —
      // see `pitch_space.dart`. A shape whose winger peaks in the middle would
      // mean the anchor arithmetic had come adrift from the coordinates the
      // squad screen draws him at, and the heatmap would be lying about a
      // player the manager can see standing there.
      final wrong = <String>[];
      for (final entry in formations.entries) {
        final side = _lineupSide(shape: entry.key);
        for (final p in side.players) {
          if (p.slotPosition == 'GK') continue;
          final slot = entry.value.slots.firstWhere(
            (s) => s.slotId == p.slotId,
          );
          final want = slot.x < 40
              ? Flank.right
              : (slot.x >= 60 ? Flank.left : Flank.centre);
          final got = zoneFlankFor(p.attacking.peakZone, theirs: false);
          if (got != want) {
            wrong.add('${entry.key}/${p.slotId} x${slot.x} '
                '${want.name} -> ${got.name}');
          }
        }
      }
      expect(wrong, isEmpty);
    });

    /// 2,000 matches of [shape] against one unchanging 4-4-2, on one lambda.
    ({Map<Flank, double> flanks, double goals, int shots}) season(String shape) {
      seeded.setSeed(77);
      final us = _lineupSide(
        shape: shape,
      ).scaledToTeam(attack: 70, defence: 70);
      final them = _side(70, '4-4-2');
      final out = <PositionalEvent>[];
      var goals = 0;
      const n = 2000;
      for (var i = 0; i < n; i++) {
        goals += positionalWindowGoals(
          ctx: SequenceContext(attackers: us, defenders: them, side: 'ours'),
          lambda: 1.35,
          fromMinute: 0,
          toMinute: 90,
          out: out,
        );
      }
      final sum = positionalSummary(out);
      return (
        flanks: flankShares(sum, 'ours'),
        goals: goals / n,
        shots: (sum['shots'] as Map)['ours'] as int,
      );
    }

    test('the widest shape attacks widest and the narrowest narrowest', () {
      // A 4-3-3's forwards stand at x 20 and 80; a 4-2-3-1 has ONE of them, in
      // the middle, behind an attacking midfielder also in the middle. Measured
      // 23.3% of shots through the centre against 36.9% — the shape doing
      // exactly what a manager picking it would expect.
      final wide = season('4-3-3');
      final narrow = season('4-2-3-1');
      expect(
        narrow.flanks[Flank.centre]!,
        greaterThan(wide.flanks[Flank.centre]! + 0.08),
        reason: '${wide.flanks} vs ${narrow.flanks}',
      );
    });

    test('and wing-backs widen a shape without changing its forwards', () {
      // 3-5-2 and 5-3-2 field the SAME two strikers at x 37 and 63. The only
      // difference is the men behind them — wing-backs at 10 and 90 against a
      // midfield three at 25, 50 and 75 — and that alone moves five points of
      // the attack off the middle. This is the cleanest "only positioning
      // changed" case in the set.
      final wingBacks = season('3-5-2');
      final three = season('5-3-2');
      expect(
        three.flanks[Flank.centre]!,
        greaterThan(wingBacks.flanks[Flank.centre]! + 0.025),
        reason: '5-3-2 ${three.flanks} vs 3-5-2 ${wingBacks.flanks}',
      );
    });

    test('a wide shape trades volume for quality, not goals', () {
      // Wide shots are worth a third of central ones, so a side that attacks
      // down the flanks needs more of them — or rather, gets FEWER and better
      // ones once the calibration has scaled the lot to lambda. Measured 9,700
      // shots for the 4-3-3 against 13,405 for the 4-2-3-1.
      final wide = season('4-3-3');
      final narrow = season('4-2-3-1');
      expect(wide.shots, lessThan((narrow.shots * 0.85).round()));
      expect(wide.shots, greaterThan(0));
    });

    test('and NO shape scores more than the goal model said it would', () {
      // The line under all of it: a shape decides where the match is played and
      // who plays it, and cannot decide how many goals a side of this quality
      // scores against a defence of that quality. 0.08 is three standard errors
      // at 2,000 matches.
      for (final shape in formations.keys) {
        expect(season(shape).goals, closeTo(1.35, 0.08), reason: shape);
      }
    });
  });
}
