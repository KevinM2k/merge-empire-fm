/// Signing a player — the action the game opens on.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Map<String, dynamic> stateWith({int coins = 100000, bool freeScout = false}) {
  final s = createDefaultState();
  (s['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  (s['shop'] as Map<String, dynamic>)['freeScoutReady'] = freeScout;
  return s;
}

int coinsOf(Map<String, dynamic> s) =>
    ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt();

int filled(Map<String, dynamic> s) =>
    ((s['grid'] as Map<String, dynamic>)['cells'] as List)
        .where((c) => c != null)
        .length;

/// A save the tier rules are live on: the tutorial is behind us and tier one is
/// marked for auto-sale. Sunday League only draws tier ones, so every card a
/// scout lands here is a candidate.
Map<String, dynamic> autoSellingState({int coins = 100000}) {
  final s = stateWith(coins: coins);
  (s['tutorial'] as Map<String, dynamic>)['done'] = true;
  // BOTH tiers Sunday League draws from. Tier two is a 15% slice of that pool,
  // so a rule covering tier one alone leaves the test flaky in exactly the way
  // a fixture that omits `variant` is.
  (s['settings'] as Map<String, dynamic>)['autoTierActions'] =
      <String, dynamic>{'1': TierAction.sell, '2': TierAction.sell};
  return s;
}

/// The app's discovery listener, in miniature.
///
/// `card:placed` fires inside the draw and the real listener answers it, so what
/// it writes is what the signing reads back. An engine test has no wiring
/// attached, so it stands one up itself.
void countDiscoveries(Map<String, dynamic> s) {
  void handler(Object? args) {
    final card = _map(args)?['card'];
    if (card is! CardInstance) return;
    final counts =
        (s['progression'] as Map<String, dynamic>)['playerFoundCounts']
            as Map<String, dynamic>;
    counts[card.discoveryKey] = ((counts[card.discoveryKey] as num?) ?? 0) + 1;
  }

  on('card:placed', handler);
  addTearDown(() => off('card:placed', handler));
}

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

void main() {
  group('the price', () {
    test('is the division base with no academy', () {
      final s = stateWith();
      expect(
        scoutCost(s),
        Scout.baseCostByDiv['sunday_league'] ?? Scout.baseCost,
      );
    });

    test('a free scout makes it nothing', () {
      expect(scoutCost(stateWith(freeScout: true)), 0);
    });

    test('but the underlying price is still askable', () {
      // The shop and the reveal both need the real figure even while a voucher
      // is covering it.
      final s = stateWith(freeScout: true);
      expect(scoutCost(s, ignoreVoucher: true), greaterThan(0));
    });

    test('the academy discounts it, and never below one coin', () {
      final s = stateWith();
      final full = scoutCost(s);
      (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.academy] = {
        'owned': true,
        'tier': 8,
        'invested': 0,
        'tapCount': 0,
      };
      final discounted = scoutCost(s);
      expect(discounted, lessThan(full));
      expect(discounted, greaterThanOrEqualTo(1));
    });
  });

  group('signing', () {
    test('an empty grid can be filled from nothing', () {
      // The state the game opens in.
      final s = stateWith();
      expect(filled(s), 0);
      expect(signBlocked(s), isNull);

      final result = signPlayer(s);
      expect(result.ok, isTrue);
      expect(result.idx, 0);
      expect(filled(s), 1);
    });

    test('charges the price', () {
      final s = stateWith(coins: 100000);
      final cost = scoutCost(s);
      signPlayer(s);
      expect(coinsOf(s), 100000 - cost);
    });

    test('counts the scout', () {
      final s = stateWith();
      signPlayer(s);
      expect((s['stats'] as Map<String, dynamic>)['totalScouts'], 1);
    });

    test('fills the next empty slot each time', () {
      final s = stateWith();
      for (var i = 0; i < 5; i++) {
        expect(signPlayer(s).idx, i, reason: 'signing $i');
      }
      expect(filled(s), 5);
    });

    test('a free scout signs without charging, and is then spent', () {
      final s = stateWith(coins: 100000, freeScout: true);
      final result = signPlayer(s);
      expect(result.ok, isTrue);
      expect(result.wasFree, isTrue);
      expect(result.cost, 0);
      expect(coinsOf(s), 100000, reason: 'no coins taken');
      expect((s['shop'] as Map<String, dynamic>)['freeScoutReady'], isFalse);
      // And the next one costs again.
      expect(scoutCost(s), greaterThan(0));
    });

    test('a skint club is refused, and keeps its coins', () {
      final s = stateWith(coins: 0);
      expect(signBlocked(s), 'insufficient_coins');
      expect(signPlayer(s).ok, isFalse);
      expect(filled(s), 0);
      expect(coinsOf(s), 0);
    });

    test('a full grid is refused, and takes nothing', () {
      final s = stateWith();
      final cells =
          (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
      for (var i = 0; i < cells.length; i++) {
        cells[i] = <String, dynamic>{'definitionId': 'x', 'instanceId': 'c$i'};
      }
      final before = coinsOf(s);
      expect(signBlocked(s), 'grid_full');
      expect(signPlayer(s).ok, isFalse);
      expect(coinsOf(s), before);
    });

    test('coins stay whole numbers', () {
      final s = stateWith();
      signPlayer(s);
      expect((s['resources'] as Map)['fanCoins'], isA<int>());
    });
  });

  group('what the reveal is told', () {
    test('a plain signing is captioned by nothing at all', () {
      final s = stateWith();
      final result = signPlayer(s);
      expect(result.isNewDiscovery, isFalse);
      expect(result.autoSell, isFalse);
      expect(result.sellCoins, 0);
      expect(result.voucherFloor, isNull);
      expect(result.voucherRandom, isFalse);
    });

    test('a free scout says a voucher paid for it, with no floor to quote', () {
      final s = stateWith(freeScout: true);
      final result = signPlayer(s);
      expect(result.voucherRandom, isTrue);
      expect(result.voucherFloor, isNull);
    });

    test('a Guaranteed Scout says which floor was promised', () {
      // Up the ladder far enough that a tier-three floor has a pool to draw
      // from — Sunday League tops out at two, so there the voucher has nothing
      // to guarantee.
      final s = stateWith();
      (s['progression'] as Map<String, dynamic>)['currentDivision'] =
          'regional_league';
      (s['shop'] as Map<String, dynamic>)['scoutVoucherTier'] = 3;
      final result = signPlayer(s);
      expect(result.ok, isTrue);
      expect(result.voucherFloor, 3);
      expect(result.voucherRandom, isFalse, reason: 'a floor is not a random');
    });

    test('a first-ever sighting is reported', () {
      final s = stateWith();
      countDiscoveries(s);
      expect(signPlayer(s).isNewDiscovery, isTrue);
    });

    test('a card already seen is not a discovery', () {
      final s = stateWith();
      countDiscoveries(s);
      // Every draw is a repeat: whatever comes out has been seen five times.
      final counts =
          (s['progression'] as Map<String, dynamic>)['playerFoundCounts']
              as Map<String, dynamic>;
      for (final def in players) {
        counts['${def.id}:m'] = 5;
        counts['${def.id}:f'] = 5;
      }
      expect(signPlayer(s).isNewDiscovery, isFalse);
    });

    test(
      'without the listener nothing is a discovery, and that is the deal',
      () {
        // Stated rather than left implicit: the count is the app's to keep, and
        // an engine run with no wiring has nobody keeping it.
        expect(signPlayer(stateWith()).isNewDiscovery, isFalse);
      },
    );

    test('a marked card is priced but NOT sold', () {
      final s = autoSellingState();
      signPlayer(s);
      final coinsBefore = coinsOf(s);
      final result = signPlayer(s);

      expect(result.autoSell, isTrue);
      expect(result.sellCoins, greaterThan(0));
      // Still in the grid, and nothing paid out: the reveal has to happen first.
      expect(filled(s), 2);
      expect(coinsOf(s), coinsBefore - result.cost);
    });

    test('the last card standing is never marked', () {
      final s = autoSellingState();
      final only = signPlayer(s);
      expect(only.autoSell, isFalse);
    });
  });

  group('the action funnel', () {
    test('a signing advances the season scout tally', () {
      final s = stateWith();
      signPlayer(s);
      signPlayer(s);
      final tally =
          (s['quests'] as Map<String, dynamic>)['seasonTally']
              as Map<String, dynamic>;
      expect(tally[QuestAction.scoutCount], 2);
    });
  });

  group('a batch', () {
    test('hands back one entry per card, in the order they landed', () {
      final s = stateWith();
      final batch = signPlayers(s, 4);
      expect(batch.placed.length, 4);
      expect([for (final p in batch.placed) p.idx], [0, 1, 2, 3]);
      expect(batch.stoppedBy, isNull);
    });

    test('only the first card is on the voucher', () {
      final s = stateWith(freeScout: true);
      final batch = signPlayers(s, 3);
      expect(batch.placed.first.voucherRandom, isTrue);
      expect(batch.placed.skip(1).every((p) => p.voucherRandom), isFalse);
      expect(
        batch.spent,
        greaterThan(0),
        reason: 'the other two were paid for',
      );
    });

    test('says so when it falls short of what was asked for', () {
      final s = stateWith(coins: 0);
      (s['shop'] as Map<String, dynamic>)['freeScoutReady'] = true;
      final heard = <Object?>[];
      void listener(Object? args) => heard.add(args);
      on('scout:short', listener);
      addTearDown(() => off('scout:short', listener));

      final batch = signPlayers(s, 4);
      expect(batch.placed.length, 1, reason: 'the free one, and no more');
      expect(batch.stoppedBy, 'insufficient_coins');
      expect(heard.single, {'got': 1, 'want': 4});
    });

    test('a batch that delivers nothing says nothing', () {
      final s = stateWith(coins: 0);
      final heard = <Object?>[];
      void listener(Object? args) => heard.add(args);
      on('scout:short', listener);
      addTearDown(() => off('scout:short', listener));

      expect(signPlayers(s, 4).placed, isEmpty);
      expect(heard, isEmpty, reason: 'the button already said why');
    });

    test('is capped at the largest size the button offers', () {
      final s = stateWith();
      expect(signPlayers(s, 99).placed.length, maxScoutBatch);
    });
  });

  group('settling the auto-sales', () {
    test('cashes in the marked cards once the reveal is over', () {
      final s = autoSellingState();
      final batch = signPlayers(s, 4);
      final marked = batch.placed.where((p) => p.autoSell).toList();
      expect(marked, isNotEmpty);

      final coinsBefore = coinsOf(s);
      final settled = settleAutoSales(s, batch.placed);

      expect(settled.sold, marked.length);
      expect(settled.coins, greaterThan(0));
      expect(coinsOf(s), coinsBefore + settled.coins);
      expect(filled(s), batch.placed.length - marked.length);
    });

    test('pays exactly what the badge quoted', () {
      final s = autoSellingState();
      final batch = signPlayers(s, 2);
      final quoted = batch.placed
          .where((p) => p.autoSell)
          .fold<num>(0, (sum, p) => sum + p.sellCoins);
      expect(settleAutoSales(s, batch.placed).coins, quoted);
    });

    test('a rule switched off mid-reveal wins', () {
      final s = autoSellingState();
      final batch = signPlayers(s, 3);
      expect(batch.placed.any((p) => p.autoSell), isTrue);

      setTierAction(s, 1, TierAction.keep);
      setTierAction(s, 2, TierAction.keep);
      final settled = settleAutoSales(s, batch.placed);

      expect(settled.sold, 0);
      expect(filled(s), 3, reason: 'every card kept');
    });

    test('announces once for the batch, keyed on the best card that went', () {
      final s = autoSellingState();
      final batch = signPlayers(s, 3);
      final sold = <Object?>[];
      void listener(Object? args) => sold.add(args);
      on('player:sold', listener);
      addTearDown(() => off('player:sold', listener));

      final settled = settleAutoSales(s, batch.placed);
      expect(sold.length, 1);
      expect((sold.single as Map)['definitionId'], settled.topSoldDef?.id);
    });

    test('a batch with nothing marked settles silently', () {
      final s = stateWith();
      final batch = signPlayers(s, 2);
      final heard = <Object?>[];
      void listener(Object? args) => heard.add(args);
      on('scout:auto_sold', listener);
      addTearDown(() => off('scout:auto_sold', listener));

      expect(settleAutoSales(s, batch.placed).sold, 0);
      expect(heard, isEmpty);
    });
  });
}
