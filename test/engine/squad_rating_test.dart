import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/formations.dart';
import 'package:merge_empire_fc/engine/match_tactics.dart';
import 'package:merge_empire_fc/engine/booking_engine.dart'
    show yellowCardRatingMult;
import 'package:merge_empire_fc/engine/squad_rating.dart';
import 'package:merge_empire_fc/state/card_instance.dart';

CardInstance _card({
  String definitionId = 'player_t5_mid',
  String instanceId = 'c1',
  bool injured = false,
  bool listed = false,
  String? loanedOut,
  String? traitId,
  int traitLevel = 1,
  double? attackRatio,
  num? energy,
}) => CardInstance({
  'instanceId': instanceId,
  'definitionId': definitionId,
  if (injured) 'injured': true,
  if (listed) 'listed': true,
  'loanedOut': ?loanedOut,
  if (traitId != null) 'trait': {'id': traitId, 'level': traitLevel},
  'attackRatio': ?attackRatio,
  'energy': ?energy,
});

/// A full XI in 4-3-3, one card per slot.
({List<CardInstance?> grid, List<Map<String, dynamic>> lineup}) _squad({
  bool injureKeeper = false,
}) {
  const defs = [
    'player_t5_gk',
    'player_t5_def', 'player_t5_def', 'player_t5_def', 'player_t5_def',
    'player_t5_mid', 'player_t5_mid', 'player_t5_mid',
    'player_t5_fwd', 'player_t5_fwd', 'player_t5_fwd',
  ];
  final slots = getFormation('4-3-3').slots;
  final grid = <CardInstance?>[
    for (var i = 0; i < defs.length; i++)
      _card(
        definitionId: defs[i],
        instanceId: 'p$i',
        injured: injureKeeper && i == 0,
      ),
  ];
  final lineup = [
    for (var i = 0; i < 11; i++)
      <String, dynamic>{
        'slotId': slots[i].slotId,
        'slotPosition': slots[i].slotPosition,
        'cardInstanceId': 'p$i',
      },
  ];
  return (grid: grid, lineup: lineup);
}

void main() {
  group('computePositionPenalty', () {
    test('no penalty in your own position', () {
      expect(computePositionPenalty('MID', 'MID'), 0);
    });

    test('a keeper anywhere else is the worst case', () {
      expect(computePositionPenalty('GK', 'FWD'), 0.50);
      expect(computePositionPenalty('FWD', 'GK'), 0.50);
    });

    test('front-to-back is nearly as bad', () {
      expect(computePositionPenalty('FWD', 'DEF'), 0.35);
      expect(computePositionPenalty('DEF', 'FWD'), 0.35);
    });

    test('an adjacent line is a mild adjustment', () {
      expect(computePositionPenalty('MID', 'FWD'), 0.20);
      expect(computePositionPenalty('DEF', 'MID'), 0.20);
    });
  });

  group('teamRatingFromSplit', () {
    test('blends 70% of the stronger department with 30% of the weaker', () {
      expect(teamRatingFromSplit(66, 65), 66);
      expect(teamRatingFromSplit(57, 51), 55);
    });

    test('is symmetric — it favours the stronger side either way round', () {
      expect(teamRatingFromSplit(85, 35), teamRatingFromSplit(35, 85));
    });

    test('a lopsided side reads ABOVE its mean, not below', () {
      // The badge under-reports exactly the damage a manager most wants
      // warning about, which is why the coach must read the split, not this.
      expect(teamRatingFromSplit(85, 35), teamRatingFromSplit(70, 70));
      expect(teamRatingFromSplit(85, 35), greaterThan((85 + 35) ~/ 2));
    });

    test('a balanced side reads at its own level', () {
      expect(teamRatingFromSplit(70, 70), 70);
    });
  });

  group('getCardStats', () {
    test('a null card or unknown definition is all zeroes', () {
      expect(getCardStats(null).rating, 0);
      expect(getCardStats(CardInstance({'definitionId': 'nope'})).rating, 0);
    });

    test('rates a plain card at its definition', () {
      final stats = getCardStats(_card());
      expect(stats.rating, 55);
      expect(stats.baseRating, 55);
    });

    test('a striker leads on attack, a keeper on defence', () {
      expect(
        getCardStats(_card(definitionId: 'player_t5_fwd')).attack,
        greaterThan(getCardStats(_card(definitionId: 'player_t5_fwd')).defence),
      );
      expect(
        getCardStats(_card(definitionId: 'player_t5_gk')).defence,
        greaterThan(getCardStats(_card(definitionId: 'player_t5_gk')).attack),
      );
    });

    test('an off-position slot drags the whole card down', () {
      final home = getCardStats(_card(definitionId: 'player_t5_gk'), slotPosition: 'GK');
      final away = getCardStats(_card(definitionId: 'player_t5_gk'), slotPosition: 'FWD');
      expect(away.rating, lessThan(home.rating));
    });

    test('a directional trait bonus is folded back into the overall', () {
      // Otherwise the card reads "+13 ATK" next to an unchanged rating.
      final plain = getCardStats(_card(definitionId: 'player_t5_fwd'));
      final withTrait = getCardStats(
        _card(definitionId: 'player_t5_fwd', traitId: 'finisher', traitLevel: 3),
      );
      expect(withTrait.attack, greaterThan(plain.attack));
      expect(withTrait.rating, greaterThan(plain.rating));
    });

    test('a trait can never push a card past its TIER ceiling', () {
      // Only a T9 Football Icon ever reads 100.
      final stats = getCardStats(
        _card(definitionId: 'player_t8_fwd', traitId: 'finisher', traitLevel: 3),
      );
      expect(stats.rating, lessThanOrEqualTo(95));
    });

    test('base stats ignore traits and penalties', () {
      final stats = getCardStats(
        _card(definitionId: 'player_t5_fwd', traitId: 'finisher', traitLevel: 3),
        slotPosition: 'GK',
      );
      expect(stats.baseRating, 56);
      expect(stats.baseAttack, greaterThan(stats.baseDefence));
    });

    test('a definition ratio is used when the card carries none', () {
      final withRatio = getCardStats(
        _card(definitionId: 'player_t5_mid'),
        definitionRatios: {'player_t5_mid': 0.9},
      );
      expect(withRatio.attack, greaterThan(withRatio.defence));
    });

    test('a per-card ratio beats the definition ratio', () {
      final stats = getCardStats(
        _card(definitionId: 'player_t5_mid', attackRatio: 0.05),
        definitionRatios: {'player_t5_mid': 0.95},
      );
      expect(stats.defence, greaterThan(stats.attack));
    });

    test('fatigue scales the whole card when asked', () {
      final fresh = getCardStats(_card(), fatigue: true);
      final tired = getCardStats(_card(energy: 5), fatigue: true);
      expect(tired.rating, lessThan(fresh.rating));
      expect(tired.attack, lessThan(fresh.attack));
    });

    test('fatigue is ignored unless requested — the sim applies its own', () {
      final tired = getCardStats(_card(energy: 5));
      expect(tired.rating, getCardStats(_card()).rating);
    });
  });

  group('weightedTeamSplit', () {
    test('an empty slot still counts in the denominator', () {
      // A short-handed side must be genuinely weaker, not merely differently
      // shaped.
      final full = weightedTeamSplit([
        for (var i = 0; i < 11; i++)
          const SplitEntry(slotPosition: 'MID', attack: 60, defence: 60),
      ]);
      final short = weightedTeamSplit([
        for (var i = 0; i < 10; i++)
          const SplitEntry(slotPosition: 'MID', attack: 60, defence: 60),
        const SplitEntry(slotPosition: 'MID', weight: 0),
      ]);
      expect(short.attack, lessThan(full.attack));
    });

    test('fractional participation prorates a player', () {
      final full = weightedTeamSplit([
        const SplitEntry(slotPosition: 'MID', attack: 100, defence: 100),
      ]);
      final half = weightedTeamSplit([
        const SplitEntry(slotPosition: 'MID', attack: 100, defence: 100, weight: 0.5),
      ]);
      expect(half.attack, lessThan(full.attack));
    });

    test('forwards drive team attack, keepers team defence', () {
      final attacking = weightedTeamSplit([
        const SplitEntry(slotPosition: 'FWD', attack: 90, defence: 20),
      ]);
      final keeping = weightedTeamSplit([
        const SplitEntry(slotPosition: 'GK', attack: 20, defence: 90),
      ]);
      expect(attacking.attack, greaterThan(attacking.defence));
      expect(keeping.defence, greaterThan(keeping.attack));
    });

    test('both stats cap at 100', () {
      final split = weightedTeamSplit([
        for (var i = 0; i < 11; i++)
          const SplitEntry(slotPosition: 'MID', attack: 500, defence: 500),
      ]);
      expect(split.attack, 100);
      expect(split.defence, 100);
    });

    test('an empty entry list is all zeroes', () {
      expect(weightedTeamSplit([]), (attack: 0, defence: 0));
    });
  });

  group('computeSquadRatings', () {
    test('an empty grid rates zero', () {
      expect(computeSquadRatings([]), (attack: 0, defence: 0));
    });

    test('a balanced squad reads about its own rating on both stats', () {
      // Weighting is what keeps this sensible — unweighted, eleven lopsided
      // specialists drag both stats well below the rating.
      final s = _squad();
      final split = computeSquadRatings(s.grid, lineup: s.lineup);
      expect(split.attack, inInclusiveRange(45, 65));
      expect(split.defence, inInclusiveRange(45, 65));
    });

    test('an injured starter weakens the side', () {
      final healthy = _squad();
      final hurt = _squad(injureKeeper: true);
      final a = computeSquadRatings(healthy.grid, lineup: healthy.lineup);
      final b = computeSquadRatings(hurt.grid, lineup: hurt.lineup);
      expect(b.defence, lessThan(a.defence));
    });

    group('A BOOKING IS AN INPUT, not something this knows about', () {
      // The port has a referee and the JS does not, so a card cannot be built
      // into this function — it is compared field for field by the parity
      // harness. It arrives as a multiplier map instead, defaulting to nothing.
      test('and no map is the JS\'s own arithmetic, unchanged', () {
        final s = _squad();
        expect(
          computeSquadRatings(
            s.grid,
            lineup: s.lineup,
            ratingMultipliers: const {},
          ),
          computeSquadRatings(s.grid, lineup: s.lineup),
        );
      });

      test('a cautioned striker takes the ATTACK down', () {
        final s = _squad();
        final clean = computeSquadRatings(s.grid, lineup: s.lineup);
        // p8, p9, p10 are the front three.
        final booked = computeSquadRatings(
          s.grid,
          lineup: s.lineup,
          ratingMultipliers: const {'p8': yellowCardRatingMult},
        );
        expect(booked.attack, lessThan(clean.attack));
      });

      test('and a cautioned keeper takes the DEFENCE down', () {
        final s = _squad();
        final clean = computeSquadRatings(s.grid, lineup: s.lineup);
        final booked = computeSquadRatings(
          s.grid,
          lineup: s.lineup,
          ratingMultipliers: const {'p0': yellowCardRatingMult},
        );
        expect(booked.defence, lessThan(clean.defence));
      });

      test('IT COSTS LESS THAN LOSING HIM, which is the whole point', () {
        // A yellow is a discount and a red is a hole. If a caution cost as much
        // as a dismissal there would be no reason to leave a booked man on.
        final s = _squad();
        final booked = computeSquadRating(
          s.grid,
          lineup: s.lineup,
          ratingMultipliers: const {'p0': yellowCardRatingMult},
        );
        final gone = computeSquadRating(
          s.grid,
          lineup: [
            for (final slot in s.lineup)
              if (slot['cardInstanceId'] == 'p0')
                <String, dynamic>{...slot, 'cardInstanceId': null}
              else
                slot,
          ],
        );
        final clean = computeSquadRating(s.grid, lineup: s.lineup);
        expect(booked, lessThan(clean));
        expect(gone, lessThan(booked));
      });

      test('and a name nobody knows changes nothing', () {
        final s = _squad();
        expect(
          computeSquadRatings(
            s.grid,
            lineup: s.lineup,
            ratingMultipliers: const {'not-in-this-squad': 0.1},
          ),
          computeSquadRatings(s.grid, lineup: s.lineup),
        );
      });
    });

    test('an unavailable player rates zero in his slot', () {
      // A loaned-out player is at another club.
      final s = _squad();
      s.grid[0]!.raw['loanedOut'] = 'rival';
      final withLoanee = computeSquadRatings(s.grid, lineup: s.lineup);

      final healthy = _squad();
      final full = computeSquadRatings(healthy.grid, lineup: healthy.lineup);
      expect(withLoanee.defence, lessThan(full.defence));
    });

    test('an empty slot weakens the side', () {
      final s = _squad();
      s.lineup[0]['cardInstanceId'] = null;
      final short = computeSquadRatings(s.grid, lineup: s.lineup);

      final healthy = _squad();
      final full = computeSquadRatings(healthy.grid, lineup: healthy.lineup);
      expect(short.defence, lessThan(full.defence));
    });

    test('falls back to the top eleven with no lineup', () {
      final s = _squad();
      final split = computeSquadRatings(s.grid);
      expect(split.attack, greaterThan(0));
      expect(split.defence, greaterThan(0));
    });

    test('the fallback skips injured and unavailable cards', () {
      final grid = <CardInstance?>[
        _card(instanceId: 'fit'),
        _card(instanceId: 'hurt', injured: true),
        _card(instanceId: 'sold', listed: true),
      ];
      final split = computeSquadRatings(grid);
      final onlyFit = computeSquadRatings([_card(instanceId: 'fit')]);
      expect(split, onlyFit);
    });

    test('a squad of only injured players rates zero', () {
      expect(
        computeSquadRatings([_card(injured: true)]),
        (attack: 0, defence: 0),
      );
    });

    test('a more attacking formation tilts the split', () {
      // Same eleven players, different shape.
      final s = _squad();
      final attacking = computeSquadRatings(s.grid, lineup: s.lineup);

      final deepSlots = getFormation('5-3-2').slots;
      final deepLineup = [
        for (var i = 0; i < 11; i++)
          <String, dynamic>{
            'slotId': deepSlots[i].slotId,
            'slotPosition': deepSlots[i].slotPosition,
            'cardInstanceId': 'p$i',
          },
      ];
      final deep = computeSquadRatings(s.grid, lineup: deepLineup);
      expect(deep.attack, lessThanOrEqualTo(attacking.attack));
    });
  });

  group('computeSquadRating', () {
    test('is the blend of the team split', () {
      final s = _squad();
      final split = computeSquadRatings(s.grid, lineup: s.lineup);
      expect(
        computeSquadRating(s.grid, lineup: s.lineup),
        teamRatingFromSplit(split.attack, split.defence),
      );
    });

    test('caps at 100', () {
      final grid = <CardInstance?>[
        for (var i = 0; i < 11; i++)
          _card(definitionId: 'player_t9_fwd', instanceId: 'p$i'),
      ];
      expect(computeSquadRating(grid), lessThanOrEqualTo(100));
    });
  });

  group('computeSquadRatingBreakdown', () {
    test('an empty grid breaks down to zero', () {
      final b = computeSquadRatingBreakdown([]);
      expect(b.total, 0);
      expect(b.playerBase, 0);
    });

    test('always divides by eleven, so a thin squad is weaker', () {
      final full = computeSquadRatingBreakdown(_squad().grid);
      final thin = computeSquadRatingBreakdown([_card(), _card(instanceId: 'c2')]);
      expect(thin.playerBase, lessThan(full.playerBase));
    });

    test('caps the total at 100', () {
      final grid = <CardInstance?>[
        for (var i = 0; i < 11; i++)
          _card(definitionId: 'player_t9_fwd', instanceId: 'p$i'),
      ];
      expect(computeSquadRatingBreakdown(grid).total, lessThanOrEqualTo(100));
    });

    test('an all-injured squad breaks down to zero', () {
      expect(
        computeSquadRatingBreakdown([_card(injured: true)]).total,
        0,
      );
    });
  });

  group('effectiveMatchRating', () {
    test('adds home advantage', () {
      expect(effectiveMatchRating(50, isHome: true, homeAdvDisplay: 4), 54);
    });

    test('caps at 100 BEFORE the relegation boost', () {
      // The boost is added at face value, matching the flat bonus the sim
      // gives to both stats.
      final r = effectiveMatchRating(
        99,
        isHome: true,
        relegationZone: true,
        homeAdvDisplay: 4,
      );
      expect(r, 100 + relegationBoost);
    });

    test('leaves an away side alone', () {
      expect(effectiveMatchRating(50), 50);
    });

    test('the relegation boost is modest — they are still bad teams', () {
      expect(relegationBoost, lessThanOrEqualTo(1.0));
    });
  });
}
