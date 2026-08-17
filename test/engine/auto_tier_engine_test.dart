import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/auto_tier_engine.dart';
import 'package:merge_empire_fc/engine/sell_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic> _card(
  String id, {
  String definitionId = 'player_t1_gk',
  int? loanMatchesLeft,
  int seasonsPlayed = 0,
}) => {
  'instanceId': id,
  'definitionId': definitionId,
  'seasonsPlayed': seasonsPlayed,
  'loanMatchesLeft': ?loanMatchesLeft,
};

Map<String, dynamic> _state({
  List<dynamic>? cells,
  Map<String, dynamic>? autoTierActions,
  bool tutorialDone = true,
  bool includeTutorial = true,
  num coins = 0,
  String division = 'regional_league',
  List<dynamic>? lineup,
}) => {
  'resources': <String, dynamic>{'fanCoins': coins},
  'settings': <String, dynamic>{'autoTierActions': ?autoTierActions},
  'progression': <String, dynamic>{'currentDivision': division},
  'grid': <String, dynamic>{'cells': cells ?? <dynamic>[]},
  'squad': <String, dynamic>{'lineup': lineup ?? <dynamic>[]},
  'transferOffers': <String, dynamic>{},
  if (includeTutorial)
    'tutorial': <String, dynamic>{'done': tutorialDone},
};

void main() {
  tearDown(clearBus);

  group('which tiers a rule may cover', () {
    test('one through seven, and nothing else', () {
      expect(autoTiers, [1, 2, 3, 4, 5, 6, 7]);
      expect(maxAutoTier, 7);
    });

    test('the chase cards are excluded in the ENGINE, not just the UI', () {
      // A hand-edited or cloud-synced save must not be able to turn them on:
      // nobody wants a chase card sold out from under them, and T9 is globally
      // unique so an auto-sale there is unrecoverable.
      final state = _state(autoTierActions: {'8': 'sell', '9': 'sell'});
      expect(getTierAction(state, 8), TierAction.keep);
      expect(getTierAction(state, 9), TierAction.keep);
    });

    test('setting one of them is refused and leaves no trace', () {
      final state = _state();
      expect(setTierAction(state, 9, TierAction.sell), TierAction.keep);
      expect(state['settings']['autoTierActions'], isEmpty);
    });
  });

  group('reading and writing rules', () {
    test('an untouched save keeps everything', () {
      final state = _state();
      for (final tier in autoTiers) {
        expect(getTierAction(state, tier), TierAction.keep);
      }
    });

    test('a rule set is a rule read', () {
      final state = _state();
      expect(setTierAction(state, 3, TierAction.sell), TierAction.sell);
      expect(getTierAction(state, 3), TierAction.sell);
    });

    test('setting keep clears the rule rather than storing it', () {
      // A tier you still want is simply ABSENT, which is what makes an
      // untouched save an empty map.
      final state = _state();
      setTierAction(state, 3, TierAction.sell);
      setTierAction(state, 3, TierAction.keep);
      expect(state['settings']['autoTierActions'], isEmpty);
    });

    test('tiers are keyed by string, matching the JS save shape', () {
      final state = _state();
      setTierAction(state, 2, TierAction.sell);
      expect(state['settings']['autoTierActions'], {'2': 'sell'});
    });

    test('a string tier reads the same as a number', () {
      final state = _state(autoTierActions: {'4': 'sell'});
      expect(getTierAction(state, '4'), TierAction.sell);
      expect(getTierAction(state, 4), TierAction.sell);
    });

    test('nonsense is kept, not crashed on', () {
      final state = _state();
      expect(getTierAction(state, null), TierAction.keep);
      expect(getTierAction(state, 'gold'), TierAction.keep);
      expect(getTierAction(null, 3), TierAction.keep);
    });

    test('a broken rules map is repaired in place', () {
      final state = _state();
      state['settings']['autoTierActions'] = 'tampered';
      expect(getTierAction(state, 3), TierAction.keep);
      expect(state['settings']['autoTierActions'], isA<Map<String, dynamic>>());
    });

    test('the active list comes out ascending', () {
      final state = _state();
      setTierAction(state, 5, TierAction.sell);
      setTierAction(state, 1, TierAction.sell);
      setTierAction(state, 3, TierAction.sell);
      expect(activeAutoTiers(state), [1, 3, 5]);
    });

    test('clearing switches everything back off', () {
      // A fresh career starts back in Sunday League where bronze is all there
      // is, so carrying the rules over would have a new save auto-selling
      // everything it scouts.
      final state = _state(autoTierActions: {'1': 'sell', '2': 'sell'});
      clearTierActions(state);
      expect(activeAutoTiers(state), isEmpty);
    });

    test('clearing leaves the real preferences alone', () {
      final state = _state(autoTierActions: {'1': 'sell'});
      state['settings']['soundEnabled'] = false;
      state['settings']['hardMode'] = true;
      clearTierActions(state);
      expect(state['settings']['soundEnabled'], isFalse);
      expect(state['settings']['hardMode'], isTrue);
    });

    test('clearing a save with no settings block is safe', () {
      expect(() => clearTierActions(<String, dynamic>{}), returnsNormally);
      expect(() => clearTierActions(null), returnsNormally);
    });
  });

  group('willAutoSell', () {
    test('yes for a card whose tier is switched on', () {
      final cells = [_card('a'), _card('b')];
      final state = _state(cells: cells, autoTierActions: {'1': 'sell'});
      expect(willAutoSell(state, cells, 0), isTrue);
    });

    test('no when the tier has no rule', () {
      final cells = [_card('a'), _card('b')];
      expect(willAutoSell(_state(cells: cells), cells, 0), isFalse);
    });

    test('never the last card standing', () {
      // That would leave an unplayable empty grid.
      final cells = [_card('a')];
      final state = _state(cells: cells, autoTierActions: {'1': 'sell'});
      expect(willAutoSell(state, cells, 0), isFalse);
    });

    test('a loanee is never ours to sell', () {
      // The coins would be fictional and the parent club would be owed one.
      final cells = [_card('a', loanMatchesLeft: 4), _card('b')];
      final state = _state(cells: cells, autoTierActions: {'1': 'sell'});
      expect(willAutoSell(state, cells, 0), isFalse);
    });

    test('rules stay dormant until the tutorial is done', () {
      // Its early steps only advance once cards land in the grid, and every
      // Sunday League draw is bronze, so a live bronze rule would soft-lock it.
      final cells = [_card('a'), _card('b')];
      final state = _state(
        cells: cells,
        autoTierActions: {'1': 'sell'},
        tutorialDone: false,
      );
      expect(willAutoSell(state, cells, 0), isFalse);
    });

    test('a save that predates the tutorial branch is not held back by it', () {
      final cells = [_card('a'), _card('b')];
      final state = _state(
        cells: cells,
        autoTierActions: {'1': 'sell'},
        includeTutorial: false,
      );
      expect(willAutoSell(state, cells, 0), isTrue);
    });

    test('an unknown definition is always kept', () {
      final cells = [
        {'instanceId': 'x', 'definitionId': 'club_asset_stadium'},
        _card('b'),
      ];
      final state = _state(cells: cells, autoTierActions: {'1': 'sell'});
      expect(willAutoSell(state, cells, 0), isFalse);
    });

    test('an empty cell, a bad index and a null list are all false', () {
      final cells = [null, _card('b'), _card('c')];
      final state = _state(cells: cells, autoTierActions: {'1': 'sell'});
      expect(willAutoSell(state, cells, 0), isFalse);
      expect(willAutoSell(state, cells, 99), isFalse);
      expect(willAutoSell(state, cells, -1), isFalse);
      expect(willAutoSell(state, null, 0), isFalse);
    });

    test('empty cells do not count toward the last-card guard', () {
      final cells = [_card('a'), null, null, null];
      final state = _state(cells: cells, autoTierActions: {'1': 'sell'});
      expect(willAutoSell(state, cells, 0), isFalse);
    });
  });

  group('applyTierAction', () {
    test('sells, clears the cell and pays out', () {
      final cells = <dynamic>[_card('a'), _card('b')];
      final state = _state(cells: cells, autoTierActions: {'1': 'sell'}, coins: 500);
      final result = applyTierAction(state, cells, 0);

      expect(result.action, TierAction.sell);
      expect(result.coins, greaterThan(0));
      expect(cells[0], isNull);
      expect(state['resources']['fanCoins'], 500 + result.coins);
    });

    test('the payout is flat market value, no market roll', () {
      // Hands-off selling is predictable; the manual sheet keeps the upside.
      final cells = <dynamic>[_card('a', definitionId: 'player_t3_def'), _card('b')];
      final state = _state(cells: cells, autoTierActions: {'3': 'sell'});
      final result = applyTierAction(state, cells, 0);
      final expected = roundCoins(
        baseSellPrice(
          getPlayerDef('player_t3_def'),
          CardInstance.from(_card('a', definitionId: 'player_t3_def')),
          state,
        ),
      );
      expect(result.coins, expected);
    });

    test('rounds the PRICE, never the balance', () {
      // roundCoins snaps to significant steps, so applying it to a large total
      // would quietly move the player's money.
      final cells = <dynamic>[_card('a'), _card('b')];
      final state = _state(
        cells: cells,
        autoTierActions: {'1': 'sell'},
        coins: 123456789,
      );
      final result = applyTierAction(state, cells, 0);
      expect(state['resources']['fanCoins'], 123456789 + result.coins);
    });

    test('keeps a card whose tier has no rule, and reports it', () {
      final cells = <dynamic>[_card('a'), _card('b')];
      final state = _state(cells: cells, coins: 100);
      final result = applyTierAction(state, cells, 0);
      expect(result.action, TierAction.keep);
      expect(result.coins, 0);
      expect(cells[0], isNotNull);
      expect(state['resources']['fanCoins'], 100);
    });

    test('a kept card still comes back with its definition attached', () {
      // The scout flow reads it to draw the reveal either way.
      final cells = <dynamic>[_card('a'), _card('b')];
      final result = applyTierAction(_state(cells: cells), cells, 0);
      expect(result.def?.id, 'player_t1_gk');
      expect(result.card?.instanceId, 'a');
    });

    test('vacates the lineup slot the sold card was holding', () {
      // The sale lands after the batch's lineup auto-fill has run, so a sold
      // card can be in the XI.
      final cells = <dynamic>[_card('a'), _card('b')];
      final lineup = <dynamic>[
        <String, dynamic>{'position': 'GK', 'cardInstanceId': 'a'},
        <String, dynamic>{'position': 'DEF', 'cardInstanceId': 'b'},
      ];
      final state = _state(
        cells: cells,
        autoTierActions: {'1': 'sell'},
        lineup: lineup,
      );
      applyTierAction(state, cells, 0);
      expect(lineup[0]['cardInstanceId'], isNull);
      expect(lineup[1]['cardInstanceId'], 'b');
    });

    test('re-checks the guards rather than trusting an earlier answer', () {
      // The scout flow leaves a reveal's worth of time between the question and
      // the sale, and the squad can change in it.
      final cells = <dynamic>[_card('a'), _card('b')];
      final state = _state(cells: cells, autoTierActions: {'1': 'sell'});
      expect(willAutoSell(state, cells, 0), isTrue);
      // Everything else is sold in the meantime — now it's the last one.
      cells[1] = null;
      expect(applyTierAction(state, cells, 0).action, TierAction.keep);
      expect(cells[0], isNotNull);
    });

    test('a bad index is a no-op', () {
      final cells = <dynamic>[_card('a'), _card('b')];
      final state = _state(cells: cells, autoTierActions: {'1': 'sell'});
      expect(applyTierAction(state, cells, 99).action, TierAction.keep);
      expect(applyTierAction(state, cells, -1).action, TierAction.keep);
    });

    test('a save with no resources block does not crash on the payout', () {
      final cells = <dynamic>[_card('a'), _card('b')];
      final state = _state(cells: cells, autoTierActions: {'1': 'sell'});
      state.remove('resources');
      expect(applyTierAction(state, cells, 0).action, TierAction.sell);
      expect(cells[0], isNull);
    });

    test('an ageing card fetches less than a fresh one', () {
      num sell(int seasons) {
        final cells = <dynamic>[
          _card('a', definitionId: 'player_t5_mid', seasonsPlayed: seasons),
          _card('b'),
        ];
        final state = _state(cells: cells, autoTierActions: {'5': 'sell'});
        return applyTierAction(state, cells, 0).coins;
      }

      expect(sell(13), lessThan(sell(0)));
    });
  });
}
