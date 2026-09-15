/// Signing a player — the action the game opens on.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/data/quests.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/scout_signing_engine.dart';
import 'package:merge_empire_fc/engine/scout_voucher_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/analytics.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/random.dart';

Map<String, dynamic> stateWith({int coins = 100000, bool freeScout = false}) {
  final s = createDefaultState();
  (s['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  (s['shop'] as Map<String, dynamic>)['freeScoutReady'] = freeScout;
  return s;
}

/// A save holding [vouchers] in the inventory, past the tutorial, in a division
/// that can actually draw them.
///
/// Two traps, both of which quietly turn a batch test into a test of something
/// else. The tutorial caps every scout at ×1 and at tier one. And a floor the
/// division's pool cannot reach makes `pickScoutDefinition` return null, so the
/// signing fails `no_candidate` and the whole batch stops — Sunday League draws
/// tiers one and two only, so a tier-5 voucher there delivers nothing at all.
///
/// **That second one is reachable in play**, which is why it is spelled out
/// here rather than just worked around: a prestige keeps the inventory and
/// drops the player back to Sunday League, so a top-division voucher can
/// outlive the division that sold it. The assignment sheet is what stops it
/// being assigned; the engine's refusal is the safety net under that, and it
/// burns nothing when it fires.
Map<String, dynamic> held(
  List<int> vouchers, {
  // Champions Cup scouts cost 960,000 apiece, so a Sunday League purse tests
  // nothing but the coin check.
  int coins = 10000000,
  String division = 'champions_cup',
}) {
  final s = stateWith(coins: coins);
  (s['tutorial'] as Map<String, dynamic>)['done'] = true;
  (s['progression'] as Map<String, dynamic>)['currentDivision'] = division;
  (s['shop'] as Map<String, dynamic>)['scoutVouchers'] = [...vouchers];
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

    test('THE CAP IS THE ROSTER, NOT THE ARRAY — 30, not 39', () {
      // **Reported from a live save: "I'm locked at 30 initially, but I have
      // 39."** `grid.cells` is 39 long because 30 plus a maxed Youth Academy's
      // 8 needs 39 with one spare; it is a fixed-length array so index-based
      // drag targets stay stable, and it is NOT the squad limit. Checking only
      // `findFirstEmpty` let a player scout their way to 39.
      final s = stateWith();
      final cells =
          (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
      expect(cells.length, greaterThan(Grid.maxPlayers), reason: 'no gap left');
      for (var i = 0; i < Grid.maxPlayers; i++) {
        cells[i] = <String, dynamic>{'definitionId': 'x', 'instanceId': 'c$i'};
      }
      final before = coinsOf(s);
      expect(signBlocked(s), 'grid_full');
      expect(signPlayer(s).ok, isFalse);
      expect(filled(s), Grid.maxPlayers, reason: 'a 31st player was signed');
      expect(coinsOf(s), before);
    });

    test('and a Youth Academy tier buys exactly one more', () {
      // The one thing that grows the cap, +1 per tier.
      final s = stateWith();
      s['clubAssets'] = <String, dynamic>{
        ...?(s['clubAssets'] as Map<String, dynamic>?),
        AssetCategory.academy: <String, dynamic>{'owned': true, 'tier': 1},
      };
      final cells =
          (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
      for (var i = 0; i < Grid.maxPlayers; i++) {
        cells[i] = <String, dynamic>{'definitionId': 'x', 'instanceId': 'c$i'};
      }
      expect(signBlocked(s), isNull, reason: 'the academy slot was not honoured');
      expect(signPlayer(s).ok, isTrue);
      expect(signBlocked(s), 'grid_full');
    });

    test('AND A BATCH CANNOT WALK PAST IT EITHER', () {
      // The JS checks the count ONCE before its batch loop and then trusts
      // `placeCard`, so a batch of four starting at 29 still lands four. Every
      // signing here goes through `signBlocked`, so the port cannot.
      final s = stateWith();
      final cells =
          (s['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
      for (var i = 0; i < Grid.maxPlayers - 1; i++) {
        cells[i] = <String, dynamic>{'definitionId': 'x', 'instanceId': 'c$i'};
      }
      for (var i = 0; i < 4; i++) {
        signPlayer(s);
      }
      expect(filled(s), Grid.maxPlayers);
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

  group('WHAT A SCOUT REPORTS', () {
    late List<({String name, Map<String, Object?> params})> sent;

    setUp(() {
      sent = [];
      setAnalyticsSink((name, params) => sent.add((name: name, params: params)));
    });

    tearDown(() => setAnalyticsSink(null));

    List<({String name, Map<String, Object?> params})> scouts() =>
        sent.where((e) => e.name == 'scout').toList();

    test('ONE EVENT PER CARD, so the count survives batching', () {
      // A batch of four reports four scouts, which is what keeps the series
      // comparable with every scout recorded before batching existed.
      signPlayers(stateWith(), 4);
      expect(scouts(), hasLength(4));
      expect(scouts().first.params['batch_size'], 4);
    });

    test('the cost is BANDED as well as raw', () {
      // It scales with the division, so the raw figure is nearly unique per
      // player and useless as a dimension on its own.
      signPlayer(stateWith());
      final e = scouts().single;
      expect(e.params['cost'], isA<num>());
      expect(e.params['cost_bucket'], isA<String>());
      expect(e.params['division'], 'sunday_league');
    });

    test('A FREE SCOUT SAYS SO, and costs nothing', () {
      signPlayer(stateWith(freeScout: true));
      final e = scouts().single;
      expect(e.params['is_free'], 1);
      expect(e.params['cost'], 0);
    });

    test('a scout with no voucher on it reports tier 0, not a missing param',
        () {
      // A missing param and a zero are different rows on a dashboard.
      signPlayer(stateWith());
      expect(scouts().single.params['voucher_tier'], 0);
    });

    test('AND A SIGNING THAT NEVER HAPPENED REPORTS NOTHING', () {
      // The draw can fail on a full grid, and an event for a card that did not
      // land would inflate the numerator of every scout funnel.
      final s = stateWith(coins: 0);
      final result = signPlayer(s);
      expect(result.ok, isFalse);
      expect(scouts(), isEmpty);
    });

    test('the ASSIGNED entry is reported, so a token is 1 and not 0', () {
      // With four different vouchers possible on one batch, telling a 🎲 token
      // apart from an ordinary coin scout is the whole value of this row.
      final s = held([anyCardVoucher]);
      signPlayer(s, voucher: anyCardVoucher);
      expect(scouts().single.params['voucher_tier'], 1);
    });
  });

  // ── Assigning vouchers to individual cards of a batch ──────────────────────

  group('the assignment', () {
    test('a voucher on slot 2 covers slot 2 and nothing else', () {
      final s = held([2]);
      final before = coinsOf(s);
      final unit = scoutCost(s, ignoreVoucher: true);
      final batch = signPlayers(s, 3, vouchers: [null, 2, null]);

      expect(batch.placed.length, 3);
      expect(batch.placed[0].cost, unit);
      expect(batch.placed[1].cost, 0);
      expect(batch.placed[2].cost, unit);
      expect(batch.spent, unit * 2);
      expect(coinsOf(s), before - unit * 2);
      // And it is the middle card that wears the pill on the reveal.
      expect(batch.placed[1].voucherFloor, 2);
      expect(batch.placed[0].voucherFloor, isNull);
      expect(batch.placed[2].voucherFloor, isNull);
    });

    test('only the assigned vouchers leave the inventory', () {
      final s = held([2, 2, 5]);
      signPlayers(s, 2, vouchers: [5, null]);
      expect(voucherInventory(s), [2, 2]);
    });

    test('several on one batch, each with its own floor', () {
      final s = held([2, 3]);
      final batch = signPlayers(s, 2, vouchers: [2, 3]);
      expect(batch.spent, 0);
      expect(batch.placed.map((p) => p.voucherFloor), [2, 3]);
      expect(voucherInventory(s), isEmpty);
    });

    test('A TOKEN IS FREE BUT PUTS NO FLOOR ON THE DRAW', () {
      // The Icon case. `voucherFloor` null is what says "no floor was applied",
      // and `voucherRandom` is the caption the reveal uses instead.
      final s = held([anyCardVoucher]);
      final batch = signPlayers(s, 1, vouchers: [anyCardVoucher]);
      expect(batch.spent, 0);
      expect(batch.placed.single.voucherFloor, isNull);
      expect(batch.placed.single.voucherRandom, isTrue);
      expect(voucherInventory(s), isEmpty);
    });

    test('no assignment at all is the old behaviour, untouched', () {
      final s = held([5]);
      final unit = scoutCost(s, ignoreVoucher: true);
      final batch = signPlayers(s, 2);
      // Held but not assigned, so both cards are paid for and the stack is
      // still there. A voucher is spent because the player spent it.
      expect(batch.spent, unit * 2);
      expect(voucherInventory(s), [5]);
    });

    test('A VOUCHER IS NEVER BURNED ON A SIGNING THAT NEVER HAPPENED', () {
      // The guard the whole read-before-draw, spend-after-land order exists
      // for. The grid fills on the second card, so the third never lands.
      final s = held([5, 6, 7]);
      final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
      for (var i = 0; i < cells.length - 2; i++) {
        cells[i] = <String, dynamic>{'definitionId': 'x', 'instanceId': 'c$i'};
      }
      final batch = signPlayers(s, 3, vouchers: [5, 6, 7]);
      expect(batch.placed.length, lessThan(3));
      // Exactly as many gone as cards that landed.
      expect(voucherInventory(s).length, 3 - batch.placed.length);
      expect(voucherInventory(s), contains(7));
    });

    test('A FLOOR THE DIVISION CANNOT REACH REFUSES, AND BURNS NOTHING', () {
      // Reachable in play: a prestige keeps the inventory and drops the player
      // back to Sunday League, which draws tiers one and two only — so a
      // top-division voucher can outlive the division that sold it. The sheet
      // refuses to assign one; this is the safety net under that, and what it
      // must not do is eat the voucher.
      final s = held([8], division: 'sunday_league');
      final before = coinsOf(s);
      final batch = signPlayers(s, 1, vouchers: [8]);
      expect(batch.placed, isEmpty);
      expect(batch.stoppedBy, 'no_candidate');
      expect(voucherInventory(s), [8], reason: 'still theirs');
      expect(coinsOf(s), before);
    });

    test('a short list leaves the rest of the batch on the coins', () {
      final s = held([4]);
      final unit = scoutCost(s, ignoreVoucher: true);
      final batch = signPlayers(s, 3, vouchers: [4]);
      expect(batch.spent, unit * 2);
    });

    test('THE DRAW SEQUENCE DOES NOT MOVE WITH THE ASSIGNMENT', () {
      // A save's whole future is seeded off this sequence, so where a voucher
      // went must not change how many values come off it. `weightedPick` takes
      // exactly one `random()` whatever the pool holds — this is that, asserted
      // from outside: the same seed, the same number of draws, so the value the
      // sequence is left on is the same either way.
      // Measured from outside, because there is no injectable seam: off a
      // fixed seed, the value the stream hands out AFTER the batch can only
      // match if the batch consumed the same number of values.
      double nextAfter(List<int?> assignment) {
        final s = held([3, 3, 3, 3]);
        setSeed(20260915);
        signPlayers(s, 4, vouchers: assignment);
        return random();
      }

      final none = nextAfter([null, null, null, null]);
      expect(nextAfter([3, null, null, null]), none);
      expect(nextAfter([null, null, 3, null]), none);
      expect(nextAfter([3, 3, 3, 3]), none);
    });
  });

  group('what the button offers', () {
    test('vouchers ADD to what the coins can buy', () {
      // 2 vouchers + coins for 2 → capacity 4, so ×4 is offered on a purse that
      // alone would only reach ×2. That IS the additive rule.
      final unit = scoutCost(held(const []), ignoreVoucher: true);
      expect(availableScoutBatchSizes(held(const [], coins: unit * 2)), [1, 2]);
      expect(availableScoutBatchSizes(held([3, 3], coins: unit * 2)), [1, 2, 4]);
    });

    test('vouchers alone carry a batch with no coins at all', () {
      final s = held([3, 3], coins: 0);
      expect(availableScoutBatchSizes(s), [1, 2]);
    });

    test('and with neither it is back to ×1', () {
      expect(availableScoutBatchSizes(stateWith(coins: 0)), [1]);
    });

    test('no vouchers is exactly what it always was', () {
      final unit = scoutCost(held(const []), ignoreVoucher: true);
      expect(availableScoutBatchSizes(held(const [], coins: unit * 4)), [1, 2, 4]);
    });

    test('THE BUTTON IS LIVE ON VOUCHERS ALONE', () {
      // It greyed out with a full tray otherwise, which is the opposite of the
      // feature: `scoutCost` quotes the full price now, so the per-card
      // `signBlocked` says `insufficient_coins` at zero coins.
      final s = held([5], coins: 0);
      expect(signBlocked(s), 'insufficient_coins');
      expect(scoutBlocked(s), isNull);
    });

    test('and dead when there is neither', () {
      expect(scoutBlocked(stateWith(coins: 0)), 'insufficient_coins');
    });

    test('a full grid still beats a full tray', () {
      final s = held([5]);
      final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
      for (var i = 0; i < cells.length; i++) {
        cells[i] = <String, dynamic>{'definitionId': 'x', 'instanceId': 'c$i'};
      }
      expect(scoutBlocked(s), 'grid_full');
    });
  });
}
