import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/attack_sequence.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/pitch_space.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

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
}
