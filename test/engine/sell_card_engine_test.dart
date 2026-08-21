/// Selling a player.
///
/// The pricing was ported with the engine; the ACT of selling lived in the JS
/// screen, so without this the grid was one-way.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/sell_card_engine.dart';
import 'package:merge_empire_fc/engine/sell_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

Map<String, dynamic> stateWithCard({
  Map<String, dynamic>? extra,
  int coins = 1000,
}) {
  final s = createDefaultState();
  (s['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  final def = players.firstWhere((p) => p.tier == 3);
  (s['grid'] as Map<String, dynamic>)['cells'][0] = <String, dynamic>{
    'definitionId': def.id,
    'instanceId': 'a',
    'variant': 0,
    ...?extra,
  };
  return s;
}

int coinsOf(Map<String, dynamic> s) =>
    ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt();

int filled(Map<String, dynamic> s) =>
    ((s['grid'] as Map<String, dynamic>)['cells'] as List)
        .where((c) => c != null)
        .length;

void main() {
  tearDown(() {
    resetSellRandom();
    resetMarketQuotes();
    clearBus();
  });

  group('the market roll', () {
    test('always lands on a rung', () {
      for (var i = 0; i < 200; i++) {
        final mult = rollMarketMult(null);
        expect(mult, greaterThanOrEqualTo(marketTiers.first.mult));
        expect(marketTiers, contains(marketTierFor(mult)));
      }
    });

    test('a rung is named by the multiplier it covers', () {
      expect(marketTierFor(0.5).labelKey, 'sell.market_lowball');
      expect(marketTierFor(1.4).labelKey, 'sell.market_fair');
      expect(marketTierFor(3.0).labelKey, 'sell.market_jackpot');
      // Below the floor still names something rather than throwing.
      expect(marketTierFor(0.0).labelKey, 'sell.market_lowball');
    });

    test('form and a sponsor shift the odds upward', () {
      // Not a guarantee — a cap keeps a jackpot earned rather than owed.
      double meanFor(Map<String, dynamic> raw) {
        setSellRandom(math.Random(42));
        var total = 0.0;
        for (var i = 0; i < 400; i++) {
          total += rollMarketMult(CardInstance.from(raw));
        }
        return total / 400;
      }

      final plain = meanFor({'instanceId': 'a'});
      final lucky = meanFor({'instanceId': 'a', 'form': 5, 'sponsor': 's'});
      expect(lucky, greaterThan(plain));
    });
  });

  group('the standing offer', () {
    test('one roll stands for its whole window', () {
      // It was rolled on every open, so closing and reopening the sheet shopped
      // for a better price — a slot machine rather than a market.
      final s = stateWithCard();
      final at = DateTime(2026, 1, 1, 12);
      final first = marketQuote(s, 'a', now: at);
      for (var i = 1; i < marketWindow.inSeconds; i++) {
        final again = marketQuote(s, 'a', now: at.add(Duration(seconds: i)));
        expect(again.mult, first.mult);
        expect(again.price, first.price);
        expect(again.refreshAt, first.refreshAt);
      }
      expect(first.refreshAt, at.add(marketWindow));
    });

    test('and the market moves once it is up', () {
      final s = stateWithCard();
      final at = DateTime(2026, 1, 1, 12);
      setSellRandom(math.Random(7));
      final first = marketQuote(s, 'a', now: at);
      // A reroll can land on the same rung, so it is the WINDOW that is
      // asserted; over this many it cannot come back identical every time.
      final mults = <double>{};
      for (var i = 1; i <= 20; i++) {
        mults.add(marketQuote(s, 'a', now: at.add(marketWindow * i)).mult);
      }
      expect(mults.length, greaterThan(1));
      expect(mults, isNot(equals({first.mult})));
    });

    test('the price is the roll, priced against the save', () {
      final s = stateWithCard();
      final quote = marketQuote(s, 'a');
      expect(quote.price, sellPriceAt(s, 'a', quote.mult));
    });

    test('a card that has left quotes nothing', () {
      final s = stateWithCard();
      sellCard(s, 'a', 1.3);
      expect(marketQuote(s, 'a').price, 0);
    });
  });

  group('selling', () {
    test('removes the card and pays for it', () {
      final s = stateWithCard();
      expect(filled(s), 1);
      final expected = sellPriceAt(s, 'a', 1.3);

      final result = sellCard(s, 'a', 1.3);
      expect(result.ok, isTrue);
      expect(result.coins, expected);
      expect(filled(s), 0);
      expect(coinsOf(s), 1000 + expected);
    });

    test('pays what the sheet quoted, not a fresh roll', () {
      // The multiplier is rolled by the caller and passed in, because the sheet
      // shows the offer before it is accepted.
      final s = stateWithCard();
      final quoted = sellPriceAt(s, 'a', 2.8);
      expect(sellCard(s, 'a', 2.8).coins, quoted);
    });

    test('a better multiplier pays more', () {
      final low = stateWithCard();
      final high = stateWithCard();
      expect(
        sellCard(high, 'a', 2.8).coins,
        greaterThan(sellCard(low, 'a', 0.5).coins),
      );
    });

    test('counts the sale', () {
      final s = stateWithCard();
      sellCard(s, 'a', 1.0);
      expect((s['stats'] as Map<String, dynamic>)['totalSold'], 1);
    });

    test('announces it, so the toast layer can say so', () {
      final s = stateWithCard();
      Object? heard;
      on('player:sold', (args) => heard = args);
      sellCard(s, 'a', 1.0);
      expect(heard, isNotNull);
      expect((heard! as Map)['instanceId'], 'a');
    });

    test('coins stay whole numbers', () {
      final s = stateWithCard();
      sellCard(s, 'a', 1.37);
      expect((s['resources'] as Map)['fanCoins'], isA<int>());
    });
  });

  group('what it refuses', () {
    test('a card that is not there', () {
      final s = stateWithCard();
      expect(sellBlocked(s, 'nope'), 'not_found');
      expect(sellCard(s, 'nope', 1.0).ok, isFalse);
      expect(filled(s), 1);
    });

    test('a loanee, who is not ours to sell', () {
      final s = stateWithCard(extra: {'loanMatchesLeft': 3});
      expect(sellBlocked(s, 'a'), 'on_loan');
      final before = coinsOf(s);
      expect(sellCard(s, 'a', 1.0).ok, isFalse);
      expect(filled(s), 1);
      expect(coinsOf(s), before);
    });

    test('a player lent out, who is at another club', () {
      final s = stateWithCard(
        extra: {
          'loanedOut': {'team': 'Ayton'},
        },
      );
      expect(sellBlocked(s, 'a'), 'loaned_out');
      expect(sellCard(s, 'a', 1.0).ok, isFalse);
      expect(filled(s), 1);
    });

    test('a player already listed', () {
      final s = stateWithCard(extra: {'listed': true});
      expect(sellBlocked(s, 'a'), 'listed');
      expect(sellCard(s, 'a', 1.0).ok, isFalse);
    });
  });
}
