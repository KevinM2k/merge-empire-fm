import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';

/// Values are pinned against `../merge-empire-fc/src/data/config.js`. A typo in
/// a constant is silent and changes game balance, so every number is asserted
/// rather than trusted — and the invariants the JS file documents in prose are
/// asserted as arithmetic.
void main() {
  test('SAVE_VERSION is 7', () {
    expect(saveVersion, 7);
  });

  test('starting coins', () {
    expect(startingCoins, 1500);
  });

  group('grid', () {
    test('dimensions', () {
      expect(Grid.cols, 3);
      expect(Grid.rows, 13);
      expect(Grid.totalCells, 39);
      expect(Grid.maxPlayers, 30);
    });

    test('cols x rows equals totalCells', () {
      expect(Grid.cols * Grid.rows, Grid.totalCells);
    });

    test('the grid holds the base roster plus a full Youth Academy', () {
      // config.js: "39 cells covers 30 + 8 with one spare". Anything that sells
      // roster slots has to check this first — a slot the grid cannot hold is a
      // slot the player cannot use.
      expect(Grid.totalCells, greaterThanOrEqualTo(Grid.maxPlayers + 8));
    });
  });

  group('club grid', () {
    test('dimensions', () {
      expect(ClubGrid.cols, 4);
      expect(ClubGrid.rows, 3);
      expect(ClubGrid.totalCells, 12);
      expect(ClubGrid.maxAssets, 12);
    });

    test('cols x rows equals totalCells', () {
      expect(ClubGrid.cols * ClubGrid.rows, ClubGrid.totalCells);
    });
  });

  group('energy', () {
    test('values', () {
      expect(Energy.max, 10);
      expect(Energy.maxUpgraded, 15);
      expect(Energy.regenMs, 600000);
      expect(Energy.regenMsUpgraded, 450000);
      expect(Energy.adReward, 3);
      expect(Energy.matchCost, 1);
      expect(Energy.adPrefetchMax, 5);
    });

    test('the upgrade shortens regen and raises the cap', () {
      expect(Energy.regenMsUpgraded, lessThan(Energy.regenMs));
      expect(Energy.maxUpgraded, greaterThan(Energy.max));
    });

    test('the ad prefetch ceiling sits below the cap', () {
      // Above this there are that many matches in hand, so the energy button is
      // not where the player is headed and a prefetch would evict a placement
      // they were about to use.
      expect(Energy.adPrefetchMax, lessThan(Energy.max));
    });
  });

  group('player energy (Pro mode fatigue)', () {
    test('values', () {
      expect(PlayerEnergy.matchFitnessCostPct, 0.09);
      expect(PlayerEnergy.inMatchDipPct, 0.16);
      expect(PlayerEnergy.fitnessFullRegenMs, 6600000);
      expect(PlayerEnergy.fitnessFullRegenMsUpgraded, 4500000);
      expect(PlayerEnergy.minFitToField, 11);
      expect(PlayerEnergy.fitThresholdPct, 0.10);
      expect(PlayerEnergy.fatigueDeadZonePct, 0.85);
      expect(PlayerEnergy.segments, 6);
      expect(PlayerEnergy.maxSubs, 5);
      expect(PlayerEnergy.adRefillPct, 0.25);
      expect(PlayerEnergy.overfillMult, 2);
      expect(PlayerEnergy.ageDrainPerSeason, 0.04);
    });

    test('strategy drain multipliers', () {
      expect(PlayerEnergy.strategyDrainMult, {
        'balanced': 1.0,
        'allOutAttack': 1.3,
        'parkTheBus': 0.85,
        'counterAttack': 0.9,
        'highPress': 1.6,
      });
    });

    test('balanced is the neutral multiplier', () {
      expect(PlayerEnergy.strategyDrainMult['balanced'], 1.0);
    });

    test('the throughput invariant: ~one match of drain back per ~10 minutes', () {
      // config.js pins Pro's games/hour to Casual's pip pool. One full 90
      // costs 9% of the bar, and the bar refills 0->100% in 110 minutes, so a
      // match's drain comes back in ~9.9 minutes — Casual's REGEN_MS is 10.
      final msPerMatchDrain =
          PlayerEnergy.fitnessFullRegenMs * PlayerEnergy.matchFitnessCostPct;
      expect(msPerMatchDrain, closeTo(Energy.regenMs, Energy.regenMs * 0.05));
    });

    test('the upgraded regen preserves that invariant against upgraded pips', () {
      final msPerMatchDrain = PlayerEnergy.fitnessFullRegenMsUpgraded *
          PlayerEnergy.matchFitnessCostPct;
      expect(
        msPerMatchDrain,
        closeTo(Energy.regenMsUpgraded, Energy.regenMsUpgraded * 0.10),
      );
    });

    test('the dead zone sits above the fit threshold', () {
      expect(
        PlayerEnergy.fatigueDeadZonePct,
        greaterThan(PlayerEnergy.fitThresholdPct),
      );
    });

    test('high press drains fastest and park the bus slowest', () {
      final mults = PlayerEnergy.strategyDrainMult;
      expect(mults['highPress'], mults.values.reduce((a, b) => a > b ? a : b));
      expect(mults['parkTheBus'], mults.values.reduce((a, b) => a < b ? a : b));
    });
  });

  group('division-keyed cost tables', () {
    const divisions = [
      'sunday_league',
      'amateur_cup',
      'regional_league',
      'national_league',
      'elite_league',
      'continental',
      'champions_cup',
    ];

    test('scout costs', () {
      expect(Scout.baseCost, 200);
      expect(Scout.baseCostByDiv, {
        'sunday_league': 200,
        'amateur_cup': 1000,
        'regional_league': 3000,
        'national_league': 10000,
        'elite_league': 30000,
        'continental': 120000,
        'champions_cup': 960000,
      });
    });

    test('asset costs', () {
      expect(Asset.baseCost, 1500);
      expect(Asset.baseCostByDiv, {
        'sunday_league': 1500,
        'amateur_cup': 7000,
        'regional_league': 25000,
        'national_league': 80000,
        'elite_league': 250000,
        'continental': 1500000,
        'champions_cup': 15000000,
      });
    });

    test('minigame bases', () {
      expect(Minigame.baseByDiv, {
        'sunday_league': 100,
        'amateur_cup': 200,
        'regional_league': 400,
        'national_league': 800,
        'elite_league': 1500,
        'continental': 7500,
        'champions_cup': 45000,
      });
      expect(Minigame.skipCapPerDay, 3);
      expect(Minigame.skipGemCost, 1);
    });

    test('every table covers all seven divisions, in ladder order', () {
      expect(Scout.baseCostByDiv.keys, divisions);
      expect(Asset.baseCostByDiv.keys, divisions);
      expect(Minigame.baseByDiv.keys, divisions);
    });

    test('every table rises monotonically up the ladder', () {
      for (final table in [
        Scout.baseCostByDiv,
        Asset.baseCostByDiv,
        Minigame.baseByDiv,
      ]) {
        final values = divisions.map((d) => table[d]!).toList();
        for (var i = 1; i < values.length; i++) {
          expect(
            values[i],
            greaterThan(values[i - 1]),
            reason: 'cost fell from ${divisions[i - 1]} to ${divisions[i]}',
          );
        }
      }
    });

    test('the sunday_league entry matches the fallback base cost', () {
      expect(Scout.baseCostByDiv['sunday_league'], Scout.baseCost);
      expect(Asset.baseCostByDiv['sunday_league'], Asset.baseCost);
    });
  });

  group('idle', () {
    test('values', () {
      expect(Idle.tickMs, 1000);
      expect(Idle.maxOfflineMs, 28800000);
      expect(Idle.boostMultiplier, 2.0);
      expect(Idle.boostDurationMs, 7200000);
      expect(Idle.offlineNotifyThresholdMs, 300000);
    });

    test('the offline cap is 8 hours', () {
      expect(Idle.maxOfflineMs, 8 * 60 * 60 * 1000);
    });

    test('the notify threshold sits well inside the offline cap', () {
      expect(Idle.offlineNotifyThresholdMs, lessThan(Idle.maxOfflineMs));
    });
  });

  test('merge requires two cards', () {
    expect(Merge.requiredCount, 2);
  });

  group('form', () {
    test('values', () {
      expect(Form.min, -1);
      expect(Form.max, 1);
      expect(Form.ratingPctPerLevel, 0.05);
    });

    test('the range is symmetric about zero', () {
      expect(Form.min, -Form.max);
    });
  });
}
