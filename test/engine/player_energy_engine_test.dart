import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

CardInstance _card({
  String definitionId = 'player_t5_fwd',
  num? energy,
  int? energyUpdatedAt,
  int seasonsPlayed = 0,
  bool injured = false,
  String? traitId,
  int traitLevel = 1,
  num? staminaOverride,
  String instanceId = 'c1',
}) => CardInstance({
  'instanceId': instanceId,
  'definitionId': definitionId,
  'seasonsPlayed': seasonsPlayed,
  if (injured) 'injured': true,
  'energy': ?energy,
  'energyUpdatedAt': ?energyUpdatedAt,
  if (traitId != null) 'trait': {'id': traitId, 'level': traitLevel},
  '_staminaDrainMult': ?staminaOverride,
});

Map<String, dynamic> _state({
  List<dynamic>? cells,
  bool hardMode = true,
  bool energyUpgraded = false,
  Map<String, dynamic>? clubAssets,
  List<dynamic>? lineup,
}) => {
  'settings': {'hardMode': hardMode},
  'shop': {'energyUpgraded': energyUpgraded},
  'grid': {'cells': cells ?? []},
  'clubAssets': clubAssets ?? <String, dynamic>{},
  'squad': {'lineup': lineup},
};

void main() {
  group('energy basics', () {
    test('max energy is the card base rating', () {
      // T5 FWD bases at 56.
      expect(getMaxEnergy(_card()), 56);
    });

    test('max energy follows a rating bonus', () {
      final card = CardInstance({
        'definitionId': 'player_t5_fwd',
        'ratingBonus': 3,
      });
      expect(getMaxEnergy(card), 59);
    });

    test('an unknown definition has no bar', () {
      expect(getMaxEnergy(CardInstance({'definitionId': 'nope'})), 0);
      expect(getMaxEnergy(null), 0);
    });

    test('an un-migrated card reads as full', () {
      expect(getEnergy(_card()), 56);
      expect(energyPct(_card()), 1.0);
    });

    test('energy clamps to the bar', () {
      expect(getEnergy(_card(energy: -5)), 0);
      expect(getEnergy(_card(energy: 999)), 56);
    });

    test('live rating is current energy', () {
      expect(liveRating(_card(energy: 30)), 30);
    });

    test('energyPct caps at 1 even with a buffer', () {
      // A fitness buffer must never lift rating above 100%.
      expect(energyPct(_card(energy: 100)), 1.0);
    });

    test('raw energy exposes the overfill buffer', () {
      expect(rawEnergy(_card(energy: 100)), 100);
      expect(rawEnergyPct(_card(energy: 112)), closeTo(2.0, 1e-9));
    });

    test('raw energy clamps at the overfill ceiling', () {
      expect(rawEnergy(_card(energy: 9999)), 56 * PlayerEnergy.overfillMult);
    });
  });

  group('fatigueRatingFactor', () {
    test('is neutral inside the dead zone', () {
      // Mild tiredness must not show in ATK/DEF.
      expect(fatigueRatingFactor(1.0), 1);
      expect(fatigueRatingFactor(PlayerEnergy.fatigueDeadZonePct), 1);
      expect(fatigueRatingFactor(0.9), 1);
    });

    test('rescales the range below the dead zone', () {
      expect(fatigueRatingFactor(PlayerEnergy.fatigueDeadZonePct / 2), closeTo(0.5, 1e-9));
    });

    test('reaches zero at empty', () {
      expect(fatigueRatingFactor(0), 0);
    });

    test('is continuous across the dead-zone boundary', () {
      final justBelow = fatigueRatingFactor(PlayerEnergy.fatigueDeadZonePct - 1e-9);
      expect(justBelow, closeTo(1, 1e-6));
    });

    test('never goes negative', () {
      expect(fatigueRatingFactor(-1), 0);
    });

    test('reads a card directly', () {
      expect(cardFatigueRatingFactor(_card()), 1);
      expect(cardFatigueRatingFactor(_card(energy: 0)), 0);
    });
  });

  group('fatigueMult', () {
    test('is neutral with no perks', () {
      expect(fatigueMult(_card(), _state()), 1);
    });

    test('a stamina trait slows drain', () {
      expect(
        fatigueMult(_card(traitId: 'iron_lungs', traitLevel: 3), _state()),
        closeTo(0.60, 1e-9),
      );
    });

    test('the Kit Sponsor asset slows drain squad-wide', () {
      final state = _state(
        clubAssets: {
          'SPONSOR': {'owned': true, 'tier': 8},
        },
      );
      expect(fatigueMult(_card(), state), closeTo(0.7, 1e-9));
    });

    test('trait and asset stack multiplicatively', () {
      final state = _state(
        clubAssets: {
          'SPONSOR': {'owned': true, 'tier': 8},
        },
      );
      expect(
        fatigueMult(_card(traitId: 'iron_lungs', traitLevel: 3), state),
        closeTo(0.60 * 0.7, 1e-9),
      );
    });

    test('an explicit override applies', () {
      expect(fatigueMult(_card(staminaOverride: 0.5), _state()), 0.5);
    });

    test('a non-positive override is ignored', () {
      expect(fatigueMult(_card(staminaOverride: 0), _state()), 1);
    });
  });

  group('positionDrainMult', () {
    test('all-out attack loads the forwards and spares the defence', () {
      expect(positionDrainMult('FWD', 'allOutAttack'), greaterThan(1.3));
      expect(positionDrainMult('DEF', 'allOutAttack'), lessThan(1));
    });

    test('park the bus loads the defence and spares the forwards', () {
      expect(positionDrainMult('DEF', 'parkTheBus'), greaterThan(1.3));
      expect(positionDrainMult('FWD', 'parkTheBus'), lessThan(1));
    });

    test('high press loads everyone outfield', () {
      for (final pos in ['DEF', 'MID', 'FWD']) {
        expect(positionDrainMult(pos, 'highPress'), greaterThan(1), reason: pos);
      }
    });

    test('an unknown strategy falls back to balanced', () {
      expect(
        positionDrainMult('MID', 'nonsense'),
        positionDrainMult('MID', 'balanced'),
      );
    });

    test('an unknown position is neutral on the tactic axis', () {
      expect(positionDrainMult('COACH', 'balanced'), 1);
    });

    test('a defence under pressure works harder', () {
      final pressured = positionDrainMult(
        'DEF',
        'balanced',
        (ourAtk: 0, ourDef: 40, oppAtk: 80, oppDef: 0),
      );
      final comfortable = positionDrainMult(
        'DEF',
        'balanced',
        (ourAtk: 0, ourDef: 80, oppAtk: 40, oppDef: 0),
      );
      expect(pressured, greaterThan(comfortable));
    });

    test('a forward pressing a strong defence works harder', () {
      final pressing = positionDrainMult(
        'FWD',
        'balanced',
        (ourAtk: 80, ourDef: 0, oppAtk: 0, oppDef: 40),
      );
      final easy = positionDrainMult(
        'FWD',
        'balanced',
        (ourAtk: 40, ourDef: 0, oppAtk: 0, oppDef: 80),
      );
      expect(pressing, greaterThan(easy));
    });

    test('the duel adjustment is capped at plus or minus 35%', () {
      final extreme = positionDrainMult(
        'DEF',
        'balanced',
        (ourAtk: 0, ourDef: 0, oppAtk: 1000, oppDef: 0),
      );
      expect(extreme, closeTo(1.35, 1e-9));
    });

    test('keepers and midfielders take the tactic bias only', () {
      final loaded = (ourAtk: 100.0, ourDef: 0.0, oppAtk: 100.0, oppDef: 0.0);
      expect(
        positionDrainMult('GK', 'balanced', loaded),
        positionDrainMult('GK', 'balanced'),
      );
      expect(
        positionDrainMult('MID', 'balanced', loaded),
        positionDrainMult('MID', 'balanced'),
      );
    });
  });

  group('drainForMinutes', () {
    test('a full 90 at balanced dips by the configured percentage', () {
      final card = _card(definitionId: 'player_t5_mid');
      final max = getMaxEnergy(card);
      final drain = drainForMinutes(card, 90, 'balanced', _state());
      // Balanced loads MID at 1.05.
      expect(drain, closeTo(PlayerEnergy.inMatchDipPct * max * 1.05, 1e-9));
    });

    test('scales linearly with minutes', () {
      final card = _card();
      final half = drainForMinutes(card, 45, 'balanced', _state());
      final full = drainForMinutes(card, 90, 'balanced', _state());
      expect(full, closeTo(half * 2, 1e-9));
    });

    test('high press tires fastest', () {
      final card = _card();
      expect(
        drainForMinutes(card, 90, 'highPress', _state()),
        greaterThan(drainForMinutes(card, 90, 'balanced', _state())),
      );
    });

    test('older players tire faster', () {
      final young = drainForMinutes(_card(), 90, 'balanced', _state());
      final old = drainForMinutes(_card(seasonsPlayed: 5), 90, 'balanced', _state());
      expect(old, closeTo(young * (1 + 5 * PlayerEnergy.ageDrainPerSeason), 1e-9));
    });

    test('a stamina perk reduces the dip', () {
      final plain = drainForMinutes(_card(), 90, 'balanced', _state());
      final perked = drainForMinutes(
        _card(traitId: 'iron_lungs', traitLevel: 3),
        90,
        'balanced',
        _state(),
      );
      expect(perked, lessThan(plain));
    });

    test('zero or negative minutes drain nothing', () {
      expect(drainForMinutes(_card(), 0, 'balanced', _state()), 0);
      expect(drainForMinutes(_card(), -10, 'balanced', _state()), 0);
    });

    test('a card with no bar drains nothing', () {
      expect(
        drainForMinutes(CardInstance({'definitionId': 'nope'}), 90, 'balanced', _state()),
        0,
      );
    });
  });

  group('drainForStrategyLog', () {
    test('a single tactic matches the direct calculation', () {
      final card = _card();
      final viaLog = drainForStrategyLog(
        card,
        [(min: 0.0, id: 'balanced')],
        90,
        0,
        _state(),
      );
      expect(viaLog, closeTo(drainForMinutes(card, 90, 'balanced', _state()), 1e-9));
    });

    test('a switch reprices only the minutes after it', () {
      final card = _card();
      final log = <StrategyLogEntry>[
        (min: 0.0, id: 'balanced'),
        (min: 45.0, id: 'highPress'),
      ];
      final total = drainForStrategyLog(card, log, 90, 0, _state());
      final expected =
          drainForMinutes(card, 45, 'balanced', _state()) +
          drainForMinutes(card, 45, 'highPress', _state());
      expect(total, closeTo(expected, 1e-9));
    });

    test('the grace period drains nothing', () {
      final card = _card();
      final log = <StrategyLogEntry>[(min: 0.0, id: 'balanced')];
      expect(drainForStrategyLog(card, log, 10, 10, _state()), 0);
    });

    test('an empty log drains nothing', () {
      expect(drainForStrategyLog(_card(), [], 90, 0, _state()), 0);
    });

    test('accrues monotonically as the match runs', () {
      final card = _card();
      final log = <StrategyLogEntry>[(min: 0.0, id: 'balanced')];
      var prev = 0.0;
      for (var m = 0.0; m <= 90; m += 10) {
        final now = drainForStrategyLog(card, log, m, 0, _state());
        expect(now, greaterThanOrEqualTo(prev));
        prev = now;
      }
    });
  });

  group('persistentMatchCost', () {
    test('a full 90 costs the configured percentage of the bar', () {
      final card = _card();
      final max = getMaxEnergy(card);
      expect(
        persistentMatchCost(card, 90, 'balanced', _state()),
        closeTo(PlayerEnergy.matchFitnessCostPct * max, 1e-9),
      );
    });

    test('is uniform across positions — only the dip is positional', () {
      final fwd = persistentMatchCost(_card(definitionId: 'player_t5_fwd'), 90, 'balanced', _state());
      final def = persistentMatchCost(_card(definitionId: 'player_t5_def'), 90, 'balanced', _state());
      final maxF = getMaxEnergy(_card(definitionId: 'player_t5_fwd'));
      final maxD = getMaxEnergy(_card(definitionId: 'player_t5_def'));
      expect(fwd / maxF, closeTo(def / maxD, 1e-9));
    });

    test('zero minutes costs nothing', () {
      expect(persistentMatchCost(_card(), 0, 'balanced', _state()), 0);
    });
  });

  group('the throughput invariant', () {
    test('a fatigue perk scales drain and recovery by the same factor', () {
      // This is the balance rule the whole engine is built around: a perk buys
      // in-match strength, never more total matches before a refill.
      const nowMs = 10000000;
      final perkState = _state(
        clubAssets: {
          'SPONSOR': {'owned': true, 'tier': 8},
        },
      );

      final plainCost = persistentMatchCost(_card(), 90, 'balanced', _state());
      final perkCost = persistentMatchCost(_card(), 90, 'balanced', perkState);
      final costRatio = perkCost / plainCost;

      final plainCard = _card(energy: 1, energyUpdatedAt: nowMs - 60000);
      final perkCard = _card(energy: 1, energyUpdatedAt: nowMs - 60000);
      final plainRecovered = processPlayerEnergyRegen(
        _state(cells: [plainCard.raw]),
        nowMs,
      );
      final perkRecovered = processPlayerEnergyRegen(
        _state(
          cells: [perkCard.raw],
          clubAssets: {
            'SPONSOR': {'owned': true, 'tier': 8},
          },
        ),
        nowMs,
      );
      final recoveryRatio = perkRecovered / plainRecovered;

      expect(recoveryRatio, closeTo(costRatio, 1e-9));
    });
  });

  group('applyDrain', () {
    test('reduces energy', () {
      final card = _card(energy: 50);
      applyDrain(card, 20);
      expect(card.energy, 30);
    });

    test('eats the overfill buffer first', () {
      final card = _card(energy: 100);
      applyDrain(card, 20);
      expect(card.energy, 80);
    });

    test('floors at zero', () {
      final card = _card(energy: 10);
      applyDrain(card, 999);
      expect(card.energy, 0);
    });

    test('a null card is a no-op', () {
      expect(applyDrain(null, 10), isNull);
    });
  });

  group('processPlayerEnergyRegen', () {
    test('does nothing in Casual mode', () {
      final card = _card(energy: 10, energyUpdatedAt: 0);
      final state = _state(cells: [card.raw], hardMode: false);
      expect(processPlayerEnergyRegen(state, 1000000), 0);
      expect(card.energy, 10);
    });

    test('recovers proportionally to elapsed time', () {
      final card = _card(energy: 0, energyUpdatedAt: 0);
      final state = _state(cells: [card.raw]);
      final max = getMaxEnergy(card);

      processPlayerEnergyRegen(state, PlayerEnergy.fitnessFullRegenMs ~/ 2);
      expect(card.energy, closeTo(max / 2, 1e-6));
    });

    test('a full bar recovers to exactly full, never past it', () {
      final card = _card(energy: 0, energyUpdatedAt: 0);
      final state = _state(cells: [card.raw]);
      processPlayerEnergyRegen(state, PlayerEnergy.fitnessFullRegenMs * 10);
      expect(card.energy, getMaxEnergy(card));
    });

    test('never clamps a paid buffer down', () {
      final card = _card(energy: 100, energyUpdatedAt: 0);
      final state = _state(cells: [card.raw]);
      processPlayerEnergyRegen(state, 1000000);
      expect(card.energy, 100);
    });

    test('the Energy Director upgrade recovers faster', () {
      final plain = _card(energy: 0, energyUpdatedAt: 0);
      final upgraded = _card(energy: 0, energyUpdatedAt: 0);

      processPlayerEnergyRegen(_state(cells: [plain.raw]), 600000);
      processPlayerEnergyRegen(
        _state(cells: [upgraded.raw], energyUpgraded: true),
        600000,
      );
      expect(upgraded.energy, greaterThan(plain.energy!));
    });

    test('stamps energyUpdatedAt', () {
      final card = _card(energy: 10, energyUpdatedAt: 0);
      processPlayerEnergyRegen(_state(cells: [card.raw]), 5000);
      expect(card.raw['energyUpdatedAt'], 5000);
    });

    test('tolerates empty slots and unknown definitions', () {
      final state = _state(cells: [null, {'definitionId': 'nope'}]);
      expect(() => processPlayerEnergyRegen(state, 1000), returnsNormally);
    });
  });

  group('fitness gating', () {
    test('a fresh card is fit', () {
      expect(isFit(_card()), isTrue);
    });

    test('an injured card is never fit', () {
      expect(isFit(_card(injured: true)), isFalse);
    });

    test('an exhausted card is not fit', () {
      expect(isFit(_card(energy: 0)), isFalse);
    });

    test('the threshold is exclusive', () {
      final card = _card(energy: 56 * PlayerEnergy.fitThresholdPct);
      expect(isFit(card), isFalse);
    });

    test('counts fit players across the grid', () {
      final state = _state(
        cells: [
          _card(instanceId: 'a').raw,
          _card(instanceId: 'b', energy: 0).raw,
          _card(instanceId: 'c', injured: true).raw,
          null,
        ],
      );
      expect(countFitPlayers(state), 1);
    });

    test('fatigue never blocks play', () {
      // Tired players make the team weaker; they never lock you out.
      expect(canFieldTeam(_state()), isTrue);
      expect(canFieldTeam(null), isTrue);
    });
  });

  group('averageFitnessPct', () {
    test('reads the XI, not the bench', () {
      // Bench players sit fresh and would otherwise inflate the number.
      final starter = _card(instanceId: 'starter', energy: 28); // 50%
      final bench = _card(instanceId: 'bench');
      final state = _state(
        cells: [starter.raw, bench.raw],
        lineup: [
          for (var i = 0; i < 11; i++)
            {'cardInstanceId': i == 0 ? 'starter' : null},
        ],
      );
      expect(averageFitnessPct(state), 50);
    });

    test('falls back to the whole squad with no lineup', () {
      final state = _state(
        cells: [_card(energy: 28).raw],
        lineup: null,
      );
      expect(averageFitnessPct(state), 50);
    });

    test('reports 100 for an empty squad', () {
      expect(averageFitnessPct(_state()), 100);
      expect(averageFitnessPct(null), 100);
    });

    test('a paid buffer shows above 100', () {
      final state = _state(cells: [_card(energy: 112).raw]);
      expect(averageFitnessPct(state), 200);
    });
  });

  group('fitnessRegenInfo', () {
    test('a full card reports full with no countdown', () {
      final info = fitnessRegenInfo(_card(), _state(), 1000);
      expect(info.full, isTrue);
      expect(info.pct, 100);
      expect(info.msToNextPoint, 0);
    });

    test('projects forward by elapsed time', () {
      final card = _card(energy: 0, energyUpdatedAt: 0);
      final info = fitnessRegenInfo(card, _state(), PlayerEnergy.fitnessFullRegenMs ~/ 2);
      expect(info.pct, 50);
      expect(info.full, isFalse);
    });

    test('counts down to the next whole point', () {
      final card = _card(energy: 10.5, energyUpdatedAt: 1000);
      final info = fitnessRegenInfo(card, _state(), 1000);
      expect(info.pointFraction, closeTo(0.5, 1e-9));
      expect(info.msToNextPoint, greaterThan(0));
    });

    test('a card with no bar reports empty', () {
      final info = fitnessRegenInfo(
        CardInstance({'definitionId': 'nope'}),
        _state(),
        1000,
      );
      expect(info.max, 0);
      expect(info.full, isTrue);
    });

    test('a buffered card reports its real raw percentage', () {
      final info = fitnessRegenInfo(_card(energy: 84), _state(), 1000);
      expect(info.pct, 150);
      expect(info.full, isTrue);
    });
  });

  group('top-ups', () {
    test('the ad refill caps at full', () {
      final card = _card(energy: 50);
      topUpAllEnergy(_state(cells: [card.raw]), 1000, PlayerEnergy.adRefillPct);
      expect(card.energy, getMaxEnergy(card));
    });

    test('a paid pack banks past full', () {
      final card = _card(energy: 50);
      topUpAllEnergy(_state(cells: [card.raw]), 1000, 1, overfill: true);
      expect(card.energy, greaterThan(getMaxEnergy(card)));
    });

    test('the buffer is capped at the overfill ceiling', () {
      final card = _card(energy: 50);
      topUpAllEnergy(_state(cells: [card.raw]), 1000, 10, overfill: true);
      expect(card.energy, getMaxEnergy(card) * PlayerEnergy.overfillMult);
    });

    test('refillAllEnergy fills to exactly full', () {
      final card = _card(energy: 0);
      refillAllEnergy(_state(cells: [card.raw]), 1000);
      expect(card.energy, getMaxEnergy(card));
    });

    test('stamps energyUpdatedAt', () {
      final card = _card(energy: 0);
      refillAllEnergy(_state(cells: [card.raw]), 4242);
      expect(card.raw['energyUpdatedAt'], 4242);
    });
  });
}
