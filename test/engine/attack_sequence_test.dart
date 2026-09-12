import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/attack_sequence.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/random.dart' as seeded;

/// A card of the tier and position a slot wants.
CardInstance _card(String id, String pos, {int tier = 5}) => CardInstance({
  'instanceId': id,
  'definitionId': 'player_t${tier}_${pos.toLowerCase()}',
});

/// A full XI in [formationId], one fit card per slot, ids equal to slot ids.
({List<CardInstance> cards, List<Map<String, dynamic>> lineup}) _xi(
  String formationId, {
  Map<String, int> tiers = const {},
  Set<String> empty = const {},
}) {
  final slots = formations[formationId]!.slots;
  final cards = <CardInstance>[];
  final lineup = <Map<String, dynamic>>[];
  for (final s in slots) {
    final has = !empty.contains(s.slotId);
    if (has) {
      cards.add(_card(s.slotId, s.slotPosition, tier: tiers[s.slotId] ?? 5));
    }
    lineup.add({
      'slotId': s.slotId,
      'slotPosition': s.slotPosition,
      'cardInstanceId': has ? s.slotId : null,
    });
  }
  return (cards: cards, lineup: lineup);
}

PitchSide _ours(String formationId, {Map<String, int> tiers = const {}}) {
  final xi = _xi(formationId, tiers: tiers);
  return pitchSideFromLineup(
    cards: xi.cards,
    lineup: xi.lineup,
    slots: formations[formationId]!.slots,
  );
}

/// Share of picks each player gets over an even sweep of the unit interval.
Map<String, double> _shares(
  PitchPlayer? Function(double roll) pick, {
  int steps = 2000,
}) {
  final counts = <String, int>{};
  var picked = 0;
  for (var i = 0; i < steps; i++) {
    final p = pick((i + 0.5) / steps);
    if (p == null) continue;
    picked++;
    counts[p.slotId] = (counts[p.slotId] ?? 0) + 1;
  }
  return {for (final e in counts.entries) e.key: e.value / picked};
}

String _top(Map<String, double> shares) =>
    shares.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

PitchPlayer _by(PitchSide side, String slotId) =>
    side.players.firstWhere((p) => p.slotId == slotId);

void main() {
  group('weightedIndex', () {
    test('walks the cumulative weights', () {
      const w = [1.0, 3.0, 0.0, 6.0];
      expect(weightedIndex(w, 0.0), 0);
      expect(weightedIndex(w, 0.099), 0);
      expect(weightedIndex(w, 0.1), 1);
      expect(weightedIndex(w, 0.399), 1);
      expect(weightedIndex(w, 0.4), 3);
      expect(weightedIndex(w, 0.999), 3);
    });

    test('never lands on a zero weight and returns null for none', () {
      expect(weightedIndex([0.0, 0.0], 0.5), isNull);
      expect(weightedIndex([], 0.5), isNull);
      for (var i = 0; i < 100; i++) {
        expect(weightedIndex([0.0, 1.0, 0.0], i / 100), 1);
      }
    });

    test('a roll at or past one lands on the last weighted entry', () {
      expect(weightedIndex([1.0, 1.0, 0.0], 1.0), 1);
      expect(weightedIndex([1.0, 1.0, 0.0], 1.5), 1);
    });
  });

  group('building our side', () {
    test('fields one player per occupied slot with the slot maps', () {
      final side = _ours('4-3-3');
      expect(side.players.length, 11);
      expect(side.players.map((p) => p.id).toSet().length, 11);
      final rf = _by(side, 'rf');
      expect(rf.slotPosition, 'FWD');
      expect(rf.attacking.mass, closeTo(attackWeights['FWD']!, 1e-9));
      expect(zoneFlank(rf.attacking.peakZone), Flank.right);
      expect(zoneBand(rf.attacking.peakZone), 0);
    });

    test('a hole in the lineup is a missing player, not a zero', () {
      final xi = _xi('4-4-2', empty: {'lm'});
      final side = pitchSideFromLineup(
        cards: xi.cards,
        lineup: xi.lineup,
        slots: formations['4-4-2']!.slots,
      );
      expect(side.players.length, 10);
      expect(side.players.any((p) => p.slotId == 'lm'), isFalse);
    });

    test('an injured or listed card does not take the field', () {
      final xi = _xi('4-4-2');
      xi.cards.firstWhere((c) => c.instanceId == 'rs').raw['injured'] = true;
      xi.cards.firstWhere((c) => c.instanceId == 'ls').raw['listed'] = true;
      final side = pitchSideFromLineup(
        cards: xi.cards,
        lineup: xi.lineup,
        slots: formations['4-4-2']!.slots,
      );
      expect(side.players.length, 9);
    });

    test('maps follow the slot, not the card', () {
      // A forward parked at right-back defends like a right-back.
      final slots = formations['4-4-2']!.slots;
      final cards = [_card('x', 'FWD')];
      final lineup = [
        for (final s in slots)
          {
            'slotId': s.slotId,
            'slotPosition': s.slotPosition,
            'cardInstanceId': s.slotId == 'rb' ? 'x' : null,
          },
      ];
      final side = pitchSideFromLineup(
        cards: cards,
        lineup: lineup,
        slots: slots,
      );
      expect(side.players.single.slotPosition, 'DEF');
      expect(
        side.players.single.defending.mass,
        closeTo(defenceWeights['DEF']!, 1e-9),
      );
      expect(zoneFlank(side.players.single.defending.peakZone), Flank.right);
    });

    test('scale multiplies both stats', () {
      final xi = _xi('4-3-3');
      final full = pitchSideFromLineup(
        cards: xi.cards,
        lineup: xi.lineup,
        slots: formations['4-3-3']!.slots,
      );
      final tired = pitchSideFromLineup(
        cards: xi.cards,
        lineup: xi.lineup,
        slots: formations['4-3-3']!.slots,
        scale: (c) => c.instanceId == 'cf' ? 0.5 : 1.0,
      );
      expect(
        _by(tired, 'cf').attack,
        closeTo(_by(full, 'cf').attack * 0.5, 1e-9),
      );
      expect(
        _by(tired, 'cf').defence,
        closeTo(_by(full, 'cf').defence * 0.5, 1e-9),
      );
      expect(_by(tired, 'cm').attack, _by(full, 'cm').attack);
    });
  });

  group('building the AI side', () {
    test(
      'is eleven mirrored pseudo-players whose split matches the team call',
      () {
        final side = pitchSideForAi(70, '4-4-2');
        expect(side.players.length, 11);
        final team = teamSplitForFormation(70, '4-4-2');
        // The same per-position split, position-weighted, is the team number.
        var aNum = 0.0, aDen = 0.0, dNum = 0.0, dDen = 0.0;
        for (final p in side.players) {
          aNum += p.attack * attackWeights[p.slotPosition]!;
          aDen += attackWeights[p.slotPosition]!;
          dNum += p.defence * defenceWeights[p.slotPosition]!;
          dDen += defenceWeights[p.slotPosition]!;
        }
        expect((aNum / aDen + 0.5).floor(), team.attack);
        expect((dNum / dDen + 0.5).floor(), team.defence);
      },
    );

    test('their keeper stands in front of the goal we attack', () {
      final side = pitchSideForAi(70, '4-3-3');
      final gk = _by(side, 'gk');
      expect(zoneBand(gk.defending.peakZone), 0);
      expect(gk.attacking.mass, 0);
    });

    test('their right-back defends our left flank', () {
      final side = pitchSideForAi(70, '4-3-3');
      expect(zoneFlank(_by(side, 'rb').defending.peakZone), Flank.left);
      expect(zoneFlank(_by(side, 'lb').defending.peakZone), Flank.right);
    });

    test('an unknown shape falls back to 4-4-2', () {
      expect(pitchSideForAi(60, 'nonsense').players.length, 11);
      expect(
        pitchSideForAi(60, null).players.map((p) => p.slotId),
        aiFormationSlots['4-4-2']!.map((s) => s.slotId),
      );
    });
  });

  group('picking the carrier', () {
    test('on the right flank in the attacking band it is the right winger', () {
      final side = _ours('4-3-3');
      final zone = _by(side, 'rf').attacking.peakZone;
      final shares = _shares((r) => pickCarrier(side, zone, r));
      expect(_top(shares), 'rf');
      expect(shares['rf'], greaterThan(0.4));
      expect(shares['lf'] ?? 0, lessThan(0.02));
    });

    test('in the middle of the attacking band it is the striker', () {
      final side = _ours('4-3-3');
      final zone = zoneIndex(2, 0);
      final shares = _shares((r) => pickCarrier(side, zone, r));
      expect(_top(shares), 'cf');
    });

    test('the keeper is never on the ball', () {
      final side = _ours('4-3-3');
      for (var z = 0; z < pitchZones; z++) {
        expect(carrierWeights(side, z)[0], 0, reason: 'zone $z');
      }
    });

    test('a better player in the same place carries more often', () {
      final plain = _ours('4-3-3');
      final star = _ours('4-3-3', tiers: {'cf': 9});
      final zone = zoneIndex(2, 0);
      final a = _shares((r) => pickCarrier(plain, zone, r))['cf']!;
      final b = _shares((r) => pickCarrier(star, zone, r))['cf']!;
      expect(_by(star, 'cf').attack, greaterThan(_by(plain, 'cf').attack));
      expect(b, greaterThan(a + 0.1));
    });

    test('returns null where nobody has attacking presence', () {
      final side = PitchSide([]);
      expect(pickCarrier(side, 0, 0.5), isNull);
    });
  });

  group('picking the defender', () {
    test('our winger on their left is met by their left-back', () {
      // Their `lb` is mirrored onto OUR right — where our `rf` attacks.
      final ours = _ours('4-3-3');
      final theirs = pitchSideForAi(70, '4-4-2');
      final zone = _by(ours, 'rf').attacking.peakZone;
      final shares = _shares((r) => pickDefender(theirs, zone, r));
      expect(zoneFlank(zone), Flank.right);
      expect(_top(shares), anyOf('lb', 'lm'));
      expect(shares['lb'], greaterThan(shares['rb'] ?? 0));
      expect(shares['lb'], greaterThan(shares['rcb'] ?? 0));
    });

    test('in front of their goal it is a centre-back or the keeper', () {
      final theirs = pitchSideForAi(70, '4-4-2');
      final zone = zoneIndex(2, 0);
      final shares = _shares((r) => pickDefender(theirs, zone, r));
      expect(_top(shares), anyOf('gk', 'rcb', 'lcb'));
      expect(
        (shares['rcb'] ?? 0) + (shares['lcb'] ?? 0) + (shares['gk'] ?? 0),
        greaterThan(0.75),
      );
    });

    test('forwards rarely defend their own box', () {
      final theirs = pitchSideForAi(70, '4-4-2');
      final zone = zoneIndex(2, 0);
      final shares = _shares((r) => pickDefender(theirs, zone, r));
      expect((shares['rs'] ?? 0) + (shares['ls'] ?? 0), lessThan(0.02));
    });
  });

  group('scaling a side', () {
    test('moves every player by the same factor and nothing else', () {
      final side = _ours('4-4-2');
      final up = side.scaled(attack: 1.1, defence: 0.9);
      for (var i = 0; i < side.players.length; i++) {
        expect(
          up.players[i].attack,
          closeTo(side.players[i].attack * 1.1, 1e-9),
        );
        expect(
          up.players[i].defence,
          closeTo(side.players[i].defence * 0.9, 1e-9),
        );
        expect(
          identical(up.players[i].attacking, side.players[i].attacking),
          isTrue,
        );
      }
      expect(
        up.attackingPresence.mass,
        closeTo(side.attackingPresence.mass, 1e-9),
      );
    });
  });

  group('runSequence', () {
    SequenceContext ctx({String side = 'ours', int us = 70, int them = 70}) {
      final ours = pitchSideForAi(us, '4-3-3', mirrored: false);
      final theirs = pitchSideForAi(them, '4-4-2');
      return side == 'ours'
          ? SequenceContext(attackers: ours, defenders: theirs, side: 'ours')
          : SequenceContext(attackers: theirs, defenders: ours, side: 'theirs');
    }

    test(
      'starts in the middle two bands and moves one band a step toward goal',
      () {
        seeded.setSeed(3);
        for (var i = 0; i < 400; i++) {
          final out = <PositionalEvent>[];
          runSequence(ctx(), 10, out);
          expect(out, isNotEmpty);
          expect(zoneBand(out.first.zone), anyOf(1, 2));
          for (var k = 1; k < out.length; k++) {
            expect(zoneBand(out[k].zone), zoneBand(out[k - 1].zone) - 1);
            expect(
              (zoneLane(out[k].zone) - zoneLane(out[k - 1].zone)).abs(),
              lessThanOrEqualTo(1),
            );
            expect(out[k - 1].type, 'duel');
            expect(out[k - 1].outcome, 'win');
          }
          for (final e in out) {
            expect(e.side, 'ours');
            expect(e.minute, 10);
            expect(e.playerId, startsWith('ai:'));
          }
        }
      },
    );

    test('the other side attacks the other way, in our frame', () {
      seeded.setSeed(4);
      for (var i = 0; i < 400; i++) {
        final out = <PositionalEvent>[];
        runSequence(ctx(side: 'theirs'), 30, out);
        expect(zoneBand(out.first.zone), anyOf(1, 2));
        for (var k = 1; k < out.length; k++) {
          expect(zoneBand(out[k].zone), zoneBand(out[k - 1].zone) + 1);
        }
        for (final e in out) {
          expect(e.side, 'theirs');
        }
      }
    });

    test(
      'a shot is the duel in the band in front of goal, and ends the move',
      () {
        seeded.setSeed(5);
        var shots = 0, blocked = 0, turnovers = 0;
        for (var i = 0; i < 2000; i++) {
          final out = <PositionalEvent>[];
          final shot = runSequence(ctx(), 50, out);
          final last = out.last;
          if (last.type == 'shot') {
            expect(zoneBand(last.zone), 0);
            expect(out.where((e) => e.type == 'shot').length, 1);
            if (shot != null) {
              shots++;
              expect(identical(shot.event, last), isTrue);
              expect(last.outcome, 'miss');
              expect(
                shot.rawXg,
                closeTo(rawShotXg(last.zone, shot.shooter), 1e-12),
              );
              expect(shot.rawXg, greaterThan(0));
            } else {
              blocked++;
              expect(last.outcome, 'blocked');
            }
          } else {
            turnovers++;
            expect(shot, isNull);
            expect(last.outcome, 'lose');
          }
        }
        // Roughly a fifth of attacks end in a shot at parity — the figure
        // `attacksPerMatch` is set against.
        expect(shots / 2000, inInclusiveRange(0.14, 0.26));
        expect(blocked, greaterThan(0));
        expect(turnovers, greaterThan(shots));
      },
    );

    test('a stronger side gets more shots away', () {
      seeded.setSeed(6);
      int shotsFor(SequenceContext c) {
        var n = 0;
        for (var i = 0; i < 3000; i++) {
          if (runSequence(c, 1, <PositionalEvent>[]) != null) n++;
        }
        return n;
      }

      final strong = shotsFor(ctx(us: 85, them: 55));
      final even = shotsFor(ctx());
      final weak = shotsFor(ctx(us: 55, them: 85));
      expect(strong, greaterThan(even + 200));
      expect(even, greaterThan(weak + 200));
    });

    test('with nobody to attack there is no move and nothing recorded', () {
      final out = <PositionalEvent>[];
      final c = SequenceContext(
        attackers: PitchSide(const []),
        defenders: pitchSideForAi(70, '4-4-2'),
        side: 'ours',
      );
      expect(runSequence(c, 1, out), isNull);
      expect(out, isEmpty);
    });

    test('effectiveDefence is the bare number while support is off', () {
      expect(supportCoeff, 0);
      expect(effectiveDefence(70, 3), 70);
      expect(effectiveDefence(70, 0), 70);
    });

    test('central shots are worth most and a better shooter more', () {
      final good = pitchSideForAi(90, '4-3-3', mirrored: false).players.last;
      final poor = pitchSideForAi(50, '4-3-3', mirrored: false).players.last;
      expect(
        rawShotXg(zoneIndex(2, 0), good),
        greaterThan(rawShotXg(zoneIndex(0, 0), good)),
      );
      expect(
        rawShotXg(zoneIndex(1, 0), good),
        greaterThan(rawShotXg(zoneIndex(0, 0), good)),
      );
      expect(
        rawShotXg(zoneIndex(2, 0), good),
        greaterThan(rawShotXg(zoneIndex(2, 0), poor)),
      );
      expect(
        rawShotXg(zoneIndex(1, 0), good),
        rawShotXg(zoneIndex(3, 0), good),
      );
    });
  });

  group('calibrateShots', () {
    test('scales raw xG so the probabilities sum to lambda', () {
      final cal = calibrateShots([0.1, 0.2, 0.3, 0.4], 1.35);
      expect(
        cal.probabilities.fold(0.0, (a, b) => a + b),
        closeTo(1.35, 1e-12),
      );
      expect(cal.overflow, 0);
      expect(cal.probabilities[3], closeTo(cal.probabilities[0] * 4, 1e-12));
    });

    test('caps a shot and hands the rest to the others', () {
      final cal = calibrateShots([0.1, 0.9], 1.2);
      expect(cal.probabilities[1], shotCap);
      expect(cal.probabilities[0], closeTo(1.2 - shotCap, 1e-12));
      expect(cal.overflow, 0);
    });

    test(
      'what the shots cannot carry comes back as overflow, total preserved',
      () {
        final cal = calibrateShots([0.2, 0.2], 3.0);
        expect(cal.probabilities, [shotCap, shotCap]);
        expect(cal.overflow, closeTo(3.0 - 2 * shotCap, 1e-12));
      },
    );

    test('a zero-weight shot gets nothing and negative lambda is nothing', () {
      final cal = calibrateShots([0.0, 0.3], 0.6);
      expect(cal.probabilities, [0.0, 0.6]);
      expect(calibrateShots([0.3], -1).probabilities, [0.0]);
      expect(calibrateShots([], 1.0).overflow, 1.0);
    });
  });

  group('positionalWindowGoals', () {
    final ours = pitchSideForAi(72, '4-3-3', mirrored: false);
    final theirs = pitchSideForAi(68, '4-4-2');

    test('the shots sum to lambda exactly with the jitter off', () {
      seeded.setSeed(11);
      for (var i = 0; i < 200; i++) {
        final out = <PositionalEvent>[];
        const lambda = 1.6;
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
        final shots = out.where(
          (e) => e.type == 'shot' && e.outcome != 'blocked',
        );
        final sum = shots.fold(0.0, (a, e) => a + (e.xg ?? 0));
        if (shots.isEmpty) continue;
        // Capped shots hand the rest to Poisson, which the events cannot show.
        if (shots.every((e) => e.xg! < shotCap)) {
          expect(sum, closeTo(lambda, 1e-9), reason: 'match $i');
        } else {
          expect(sum, lessThanOrEqualTo(lambda + 1e-9));
        }
        for (final e in shots) {
          expect(e.outcome, anyOf('goal', 'miss'));
        }
      }
    });

    test('expected goals are lambda with the jitter on', () {
      seeded.setSeed(12);
      const lambda = 1.4;
      const n = 6000;
      var goals = 0;
      for (var i = 0; i < n; i++) {
        goals += positionalWindowGoals(
          ctx: SequenceContext(
            attackers: ours,
            defenders: theirs,
            side: 'ours',
          ),
          lambda: lambda,
          fromMinute: 0,
          toMinute: 90,
          out: <PositionalEvent>[],
        );
      }
      // Standard error is about 0.017 at this count.
      expect(goals / n, closeTo(lambda, 0.06));
    });

    test('goals in the record match the goals returned', () {
      seeded.setSeed(13);
      for (var i = 0; i < 100; i++) {
        final out = <PositionalEvent>[];
        final g = positionalWindowGoals(
          ctx: SequenceContext(
            attackers: ours,
            defenders: theirs,
            side: 'ours',
          ),
          lambda: 1.3,
          fromMinute: 0,
          toMinute: 90,
          out: out,
          jitter: 0,
        );
        final recorded = out.where((e) => e.outcome == 'goal').length;
        // Any difference is the Poisson overflow, which only capped shots make.
        if (out.every((e) => (e.xg ?? 0) < shotCap)) {
          expect(g, recorded, reason: 'match $i');
        } else {
          expect(g, greaterThanOrEqualTo(recorded));
        }
      }
    });

    test(
      'attacks are spread across the window and never before minute one',
      () {
        seeded.setSeed(14);
        final out = <PositionalEvent>[];
        positionalWindowGoals(
          ctx: SequenceContext(
            attackers: ours,
            defenders: theirs,
            side: 'ours',
          ),
          lambda: 1.0,
          fromMinute: 30,
          toMinute: 60,
          out: out,
        );
        expect(
          out.map((e) => e.minute).reduce((a, b) => a < b ? a : b),
          greaterThanOrEqualTo(30),
        );
        expect(
          out.map((e) => e.minute).reduce((a, b) => a > b ? a : b),
          lessThanOrEqualTo(60),
        );
        expect(out.map((e) => e.minute).toSet().length, greaterThan(5));
        final full = <PositionalEvent>[];
        positionalWindowGoals(
          ctx: SequenceContext(
            attackers: ours,
            defenders: theirs,
            side: 'ours',
          ),
          lambda: 1.0,
          fromMinute: 0,
          toMinute: 90,
          out: full,
        );
        expect(full.first.minute, greaterThanOrEqualTo(1));
      },
    );

    test(
      'a window too short for an attack falls back to Poisson and records nothing',
      () {
        seeded.setSeed(15);
        final out = <PositionalEvent>[];
        var goals = 0;
        for (var i = 0; i < 2000; i++) {
          goals += positionalWindowGoals(
            ctx: SequenceContext(
              attackers: ours,
              defenders: theirs,
              side: 'ours',
            ),
            lambda: 0.5,
            fromMinute: 89,
            toMinute: 90,
            out: out,
          );
        }
        expect(out, isEmpty);
        expect(goals / 2000, closeTo(0.5, 0.06));
      },
    );

    test('an empty side falls back to Poisson at lambda', () {
      seeded.setSeed(16);
      final out = <PositionalEvent>[];
      var goals = 0;
      for (var i = 0; i < 2000; i++) {
        goals += positionalWindowGoals(
          ctx: SequenceContext(
            attackers: PitchSide(const []),
            defenders: theirs,
            side: 'ours',
          ),
          lambda: 1.2,
          fromMinute: 0,
          toMinute: 90,
          out: out,
        );
      }
      expect(out, isEmpty);
      expect(goals / 2000, closeTo(1.2, 0.08));
    });

    test('a negative or zero lambda scores nothing', () {
      seeded.setSeed(17);
      for (var i = 0; i < 50; i++) {
        expect(
          positionalWindowGoals(
            ctx: SequenceContext(
              attackers: ours,
              defenders: theirs,
              side: 'ours',
            ),
            lambda: 0,
            fromMinute: 0,
            toMinute: 90,
            out: <PositionalEvent>[],
          ),
          0,
        );
      }
    });
  });

  group('PositionalEvent.toMap', () {
    test('writes the short keys and rounds xG to three places', () {
      final e = PositionalEvent(
        minute: 12,
        zone: 7,
        side: 'ours',
        playerId: 'c1',
        opponentId: 'ai:rb',
        type: 'shot',
        outcome: 'goal',
        xg: 0.123456,
      );
      expect(e.toMap(), {
        'm': 12,
        'z': 7,
        's': 'ours',
        'p': 'c1',
        'op': 'ai:rb',
        't': 'shot',
        'o': 'goal',
        'xg': 0.123,
      });
      final d = PositionalEvent(
        minute: 1,
        zone: 0,
        side: 'theirs',
        playerId: 'x',
        type: 'duel',
        outcome: 'lose',
      );
      expect(d.toMap().containsKey('op'), isFalse);
      expect(d.toMap().containsKey('xg'), isFalse);
    });
  });
}
