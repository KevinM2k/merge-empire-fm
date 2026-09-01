import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/player_energy_engine.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/util/analytics.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/engine/coin_sink_engine.dart' show trophyPolishMs;
import 'package:merge_empire_fc/util/time.dart';

int _clock = 1700000000000;

Map<String, dynamic> _state({
  int gems = 0,
  Map<String, dynamic>? grants,
  Map<String, dynamic>? shop,
  Map<String, dynamic>? boosts,
  int seasonCount = 1,
  bool hardMode = false,
  List<dynamic>? gemUnlocks,
  int energyCurrent = 0,
  List<dynamic>? cells,
}) => {
  'resources': <String, dynamic>{'gems': gems, 'fanCoins': 0},
  'gemGrants': grants,
  'shop': shop ?? <String, dynamic>{},
  'boosts': boosts ?? <String, dynamic>{},
  'settings': <String, dynamic>{'hardMode': hardMode},
  'progression': <String, dynamic>{'seasonCount': seasonCount},
  'energy': <String, dynamic>{'current': energyCurrent, 'lastRegenAt': _clock},
  'gemUnlocks': ?gemUnlocks,
  'grid': <String, dynamic>{'cells': cells ?? <dynamic>[]},
};

void main() {
  setUp(() {
    _clock = 1700000000000;
    setClock(() => _clock);
  });
  tearDown(() {
    resetClock();
    clearBus();
    setAnalyticsSink(null);
  });

  group('the balance', () {
    test('reads the save', () {
      expect(getGems(_state(gems: 7)), 7);
    });

    test('an empty or missing wallet is zero, never null', () {
      expect(getGems(<String, dynamic>{}), 0);
      expect(getGems(null), 0);
      expect(getGems({'resources': <String, dynamic>{}}), 0);
    });

    test('a corrupt balance reads as zero rather than throwing', () {
      expect(getGems({'resources': {'gems': double.nan}}), 0);
      expect(getGems({'resources': {'gems': -5}}), 0);
      expect(getGems({'resources': {'gems': 'lots'}}), 0);
    });

    test('a fractional balance floors — you cannot spend half a gem', () {
      expect(getGems({'resources': {'gems': 4.9}}), 4);
    });

    test('affordability is just the balance against the price', () {
      final state = _state(gems: 5);
      expect(canAffordGems(state, 5), isTrue);
      expect(canAffordGems(state, 6), isFalse);
      expect(canAffordGems(state, 0), isTrue);
    });
  });

  group('addGems', () {
    test('credits, announces and reports what it added', () {
      final state = _state(gems: 2);
      Object? announced;
      on('gems:updated', (v) => announced = v);
      expect(addGems(state, 3, 'cup_first_win'), 3);
      expect(getGems(state), 5);
      expect(announced, 5);
    });

    test('records the reason for analytics', () {
      final events = <(String, Map<String, Object?>)>[];
      setAnalyticsSink((name, params) => events.add((name, params)));
      addGems(_state(gems: 1), 4, 'iap');
      expect(events.single.$1, 'gems_earned');
      expect(events.single.$2['reason'], 'iap');
      expect(events.single.$2['amount'], 4);
      expect(events.single.$2['balance'], 5);
    });

    test('adds nothing for zero, a negative, or a broken amount', () {
      final state = _state(gems: 3);
      expect(addGems(state, 0), 0);
      expect(addGems(state, -5), 0);
      expect(addGems(state, double.nan), 0);
      expect(getGems(state), 3);
    });

    test('floors a fractional award', () {
      final state = _state();
      expect(addGems(state, 2.9), 2);
      expect(getGems(state), 2);
    });

    test('builds the resources block on a save that has none', () {
      final state = <String, dynamic>{};
      expect(addGems(state, 3), 3);
      expect(getGems(state), 3);
    });

    test('a null save is a no-op', () {
      expect(addGems(null, 5), 0);
    });
  });

  group('spendGems', () {
    test('debits and announces', () {
      final state = _state(gems: 9);
      Object? announced;
      on('gems:updated', (v) => announced = v);
      expect(spendGems(state, 4, 'item:x'), isTrue);
      expect(getGems(state), 5);
      expect(announced, 5);
    });

    test('refuses and changes NOTHING when the balance is short', () {
      // The check and the debit are one step, so there is no window between
      // them for a second tap to slip through.
      final state = _state(gems: 3);
      expect(spendGems(state, 4), isFalse);
      expect(getGems(state), 3);
    });

    test('spending the whole balance is allowed', () {
      final state = _state(gems: 4);
      expect(spendGems(state, 4), isTrue);
      expect(getGems(state), 0);
    });

    test('a negative or broken cost is refused', () {
      final state = _state(gems: 5);
      expect(spendGems(state, -1), isFalse);
      expect(spendGems(state, double.infinity), isFalse);
      expect(getGems(state), 5);
    });

    test('a zero cost succeeds and takes nothing', () {
      final state = _state(gems: 5);
      expect(spendGems(state, 0), isTrue);
      expect(getGems(state), 5);
    });

    test('records the reason for analytics', () {
      final events = <(String, Map<String, Object?>)>[];
      setAnalyticsSink((name, params) => events.add((name, params)));
      spendGems(_state(gems: 9), 4, 'item:energy_refill');
      expect(events.single.$1, 'gems_spent');
      expect(events.single.$2['reason'], 'item:energy_refill');
    });

    test('a null save is refused', () {
      expect(spendGems(null, 1), isFalse);
    });
  });

  group('cup wins', () {
    test('every cup pays one gem, flat', () {
      expect(gemCupRewards.values.toSet(), {1});
      expect(gemCupRewards.length, 4);
    });

    test('the four cups together are worth less than one look pack', () {
      // They are a TASTE, not a funding route: the first gems most players ever
      // hold, and enough to buy exactly one thing.
      final total = gemCupRewards.values.reduce((a, b) => a + b);
      expect(total, lessThan(packGemCost() + 1));
    });

    test('a first lift pays', () {
      final state = _state();
      expect(awardCupGems(state, 'regional_cup'), 1);
      expect(getGems(state), 1);
    });

    test('a second lift of the same cup pays nothing', () {
      // Cups run once a season and a run is about twenty seasons, so a
      // repeatable award compounds into pounds of free currency per run.
      final state = _state();
      awardCupGems(state, 'regional_cup');
      expect(awardCupGems(state, 'regional_cup'), 0);
      expect(getGems(state), 1);
    });

    test('a different cup still pays', () {
      final state = _state();
      awardCupGems(state, 'regional_cup');
      expect(awardCupGems(state, 'national_cup'), 1);
      expect(getGems(state), 2);
    });

    test('an unknown cup mints nothing rather than throwing', () {
      // An event cup added later must not be able to print currency.
      final state = _state();
      expect(awardCupGems(state, 'summer_invitational'), 0);
      expect(awardCupGems(state, null), 0);
      expect(getGems(state), 0);
    });

    test('the ledger is lifetime — a New Team reset cannot re-arm it', () {
      final state = _state(
        grants: {
          'tutorialGranted': true,
          'divisionFirsts': <dynamic>[],
          'cupFirsts': <dynamic>['world_club_cup'],
          'firstPrestigeDone': false,
          'chlTitleThisRun': false,
        },
      );
      expect(awardCupGems(state, 'world_club_cup'), 0);
    });

    test('a save whose ledger predates cupFirsts is repaired, not crashed', () {
      final state = _state(grants: {'tutorialGranted': true});
      expect(awardCupGems(state, 'regional_cup'), 1);
      expect(state['gemGrants']['cupFirsts'], ['regional_cup']);
    });
  });

  group('the one-time faucets', () {
    test('the tutorial hands over exactly one look pack', () {
      // Cups are the only other route and they don't start until the third
      // division, so without this a new player meets the gem shop with an empty
      // wallet and no idea what the currency is for.
      expect(gemAwards['tutorial'], packGemCost());
      final state = _state();
      expect(grantTutorialGems(state), 5);
      expect(getGems(state), 5);
    });

    test('and only once', () {
      final state = _state();
      grantTutorialGems(state);
      expect(grantTutorialGems(state), 0);
      expect(getGems(state), 5);
    });

    test('only the top three divisions pay a first-reach bonus', () {
      expect(gemDivisionFirsts, ['elite_league', 'continental', 'champions_cup']);
      final state = _state();
      expect(grantDivisionFirstGems(state, 'regional_league'), 0);
      expect(grantDivisionFirstGems(state, 'elite_league'), 1);
      expect(getGems(state), 1);
    });

    test('each division pays once, ever', () {
      final state = _state();
      grantDivisionFirstGems(state, 'continental');
      expect(grantDivisionFirstGems(state, 'continental'), 0);
      expect(grantDivisionFirstGems(state, 'champions_cup'), 1);
      expect(getGems(state), 2);
    });

    test('reaching a division reads the LIFETIME ledger, not divisionsUnlocked', () {
      // divisionsUnlocked is rebuilt from scratch by every reset, so keying off
      // it would pay out again on each New Team.
      final state = _state(
        grants: {
          'tutorialGranted': true,
          'divisionFirsts': <dynamic>['elite_league'],
          'cupFirsts': <dynamic>[],
          'firstPrestigeDone': false,
          'chlTitleThisRun': false,
        },
      );
      state['progression']['divisionsUnlocked'] = ['sunday_league'];
      expect(grantDivisionFirstGems(state, 'elite_league'), 0);
    });

    test('the league title pays once per RUN, unlike the rest', () {
      final state = _state();
      expect(grantChampionsTitleGems(state), 1);
      expect(grantChampionsTitleGems(state), 0);
      // Prestige clears this one flag deliberately, so the new adventure can
      // win its own Champions League.
      state['gemGrants']['chlTitleThisRun'] = false;
      expect(grantChampionsTitleGems(state), 1);
    });

    test('prestige pays every time, and the FIRST one pays a bonus', () {
      final state = _state();
      expect(grantPrestigeGems(state), gemAwards['prestige']! + gemAwards['firstPrestige']!);
      expect(grantPrestigeGems(state), gemAwards['prestige']);
    });

    test('the first-prestige bonus is gated on the ledger, not prestige.level', () {
      // Otherwise it is re-earnable by resetting.
      final state = _state(
        grants: {
          'tutorialGranted': true,
          'divisionFirsts': <dynamic>[],
          'cupFirsts': <dynamic>[],
          'firstPrestigeDone': true,
          'chlTitleThisRun': false,
        },
      );
      state['prestige'] = {'level': 0};
      expect(grantPrestigeGems(state), gemAwards['prestige']);
    });

    test('the whole lifetime faucet stays under two thirds of the cosmetic set', () {
      // A player should reach the gem shop WANTING gems. The full set is ten
      // packs; the faucet is the tutorial, three division firsts, the title,
      // the first prestige and the streak.
      final lifetime = gemAwards['tutorial']! +
          gemAwards['divisionFirst']! * gemDivisionFirsts.length +
          gemAwards['chlTitle']! +
          gemAwards['firstPrestige']! +
          gemAwards['streak7']! +
          gemCupRewards.values.reduce((a, b) => a + b);
      final fullSet = packGemCost() * 10;
      expect(lifetime, lessThan(fullSet * 2 / 3));
    });

    test('every faucet builds the ledger on a save that has none', () {
      for (final grant in [
        grantTutorialGems,
        grantChampionsTitleGems,
        grantPrestigeGems,
      ]) {
        final state = <String, dynamic>{};
        expect(grant(state), greaterThan(0));
        expect(state['gemGrants'], isA<Map<String, dynamic>>());
      }
    });
  });

  group('the catalogue', () {
    test('every live item has a price a cup win can build toward', () {
      for (final item in getLiveGemItems()) {
        expect(item.cost, greaterThan(0), reason: item.id);
      }
    });

    test('the cheapest thing in the shop costs exactly one cup win', () {
      // Which is what finally makes a first lift buy something on its own.
      final cheapest = getLiveGemItems()
          .map((i) => i.cost)
          .reduce((a, b) => a < b ? a : b);
      expect(cheapest, gemCupRewards.values.reduce((a, b) => a > b ? a : b));
    });

    test('ids are unique', () {
      final ids = gemItems.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('lookup answers for a known id and null for anything else', () {
      expect(getGemItem('energy_refill')?.cost, 5);
      expect(getGemItem('nonsense'), isNull);
    });

    test('a dormant row is not offered', () {
      expect(getLiveGemItems().every((i) => i.live), isTrue);
    });

    test('ownership reads gemUnlocks, which survives a reset', () {
      // shop.purchasedIds is filtered on reset and would drop these.
      expect(ownsGemItem(_state(gemUnlocks: ['some_permanent']), 'some_permanent'), isTrue);
      expect(ownsGemItem(_state(), 'some_permanent'), isFalse);
      expect(ownsGemItem(null, 'some_permanent'), isFalse);
    });
  });

  group('gemItemBlocked', () {
    test('nothing blocks an affordable live item', () {
      expect(gemItemBlocked(_state(gems: 10), 'energy_refill'), isNull);
    });

    test('an unknown id', () {
      expect(gemItemBlocked(_state(gems: 99), 'nonsense'), 'unknown_item');
    });

    test('an empty wallet', () {
      expect(gemItemBlocked(_state(gems: 0), 'energy_refill'), 'insufficient_gems');
    });

    test('one short is still short', () {
      expect(gemItemBlocked(_state(gems: 4), 'energy_refill'), 'insufficient_gems');
    });

    test('an effect already in force blocks a second sale', () {
      // These effects are FLAGS rather than counters, so a second purchase
      // overwrites a flag that is already set and takes the gems for nothing.
      final state = _state(gems: 20, shop: {'freeScoutReady': true});
      expect(gemItemBlocked(state, 'scout_voucher_gem'), 'already_held');
    });

    test('an armed voucher FLOOR blocks the gamble too', () {
      // The other half of the one-voucher-at-a-time rule. The scout voucher
      // engine can't be imported by the gem engine (that would be a cycle), so
      // this pins the inlined scalar read against the same rule.
      final state = _state(gems: 20, shop: {'scoutVoucherTier': 4});
      expect(gemItemBlocked(state, 'scout_voucher_gem'), 'already_held');
    });

    test('a tier-1 floor is not an armed voucher', () {
      final state = _state(gems: 20, shop: {'scoutVoucherTier': 1});
      expect(gemItemBlocked(state, 'scout_voucher_gem'), isNull);
    });

    test('a RUNNING trophy polish blocks another', () {
      setClock(() => 1000);
      addTearDown(resetClock);
      final state = _state(
        gems: 20,
        seasonCount: 4,
        boosts: {'trophyPolishUntil': 1000 + trophyPolishMs},
      );
      expect(gemItemBlocked(state, 'trophy_polish_gem'), 'already_held');
    });

    test('a spent one does not — the window ran out', () {
      setClock(() => 1000);
      addTearDown(resetClock);
      final state = _state(
        gems: 20,
        seasonCount: 4,
        boosts: {'trophyPolishUntil': 1000},
      );
      expect(gemItemBlocked(state, 'trophy_polish_gem'), isNull);
    });

    test('the Energy Refill has no held check — two tanks really are two', () {
      final state = _state(gems: 20, energyCurrent: 10);
      expect(gemItemBlocked(state, 'energy_refill'), isNull);
    });
  });

  group('buyGemItem', () {
    test('debits and reports the item', () {
      final state = _state(gems: 10);
      final result = buyGemItem(state, 'energy_refill');
      expect(result.ok, isTrue);
      expect(result.item?.id, 'energy_refill');
      expect(getGems(state), 5);
    });

    test('a blocked purchase takes nothing and says why', () {
      final state = _state(gems: 1);
      final result = buyGemItem(state, 'energy_refill');
      expect(result.ok, isFalse);
      expect(result.reason, 'insufficient_gems');
      expect(getGems(state), 1);
    });

    test('the scout voucher arms a free scout', () {
      final state = _state(gems: 5);
      expect(buyGemItem(state, 'scout_voucher_gem').ok, isTrue);
      expect(state['shop']['freeScoutReady'], isTrue);
      expect(getGems(state), 4);
    });

    test('the energy refill banks a whole tank, over the cap', () {
      // Small on purpose: energy paces matches, and matches pace the whole coin
      // economy, so a refill big enough to feel premium would be selling
      // progression rather than convenience.
      final state = _state(gems: 10, energyCurrent: 8);
      buyGemItem(state, 'energy_refill');
      expect(state['energy']['current'], 8 + Energy.max);
    });

    test('the refill tracks the CAP, so the Energy Director improves it', () {
      // A hardcoded ten would leave the £7.99 purchase doing nothing here.
      final state = _state(gems: 10, shop: {'energyUpgraded': true});
      buyGemItem(state, 'energy_refill');
      expect(state['energy']['current'], Energy.maxUpgraded);
      expect(getEnergyMax(state), Energy.maxUpgraded);
    });

    test('the refill announces the new total', () {
      final state = _state(gems: 10, energyCurrent: 1);
      Object? announced;
      on('energy:updated', (v) => announced = v);
      buyGemItem(state, 'energy_refill');
      expect(announced, 1 + Energy.max);
    });

    test('in Pro mode the refill tops up squad fitness instead', () {
      // Pro has no team pip pool at all, so a refill banks a full extra bar of
      // player fitness.
      final card = <String, dynamic>{
        'instanceId': 'c1',
        'definitionId': 'player_t5_mid',
        'seasonsPlayed': 0,
        'energy': 5.0,
      };
      final state = _state(gems: 10, hardMode: true, cells: [card]);
      final before = state['energy']['current'];
      buyGemItem(state, 'energy_refill');
      expect(state['energy']['current'], before, reason: 'pips untouched');
      final instance = CardInstance.from(card)!;
      expect(rawEnergy(instance), greaterThan(5.0));
    });

    test('the trophy polish is stamped with a HALF-HOUR DEADLINE', () {
      // It used to be stamped with the SEASON, so what eight gems bought
      // depended on how much of the season happened to be left.
      setClock(() => 1000);
      addTearDown(resetClock);
      final state = _state(gems: 20, seasonCount: 6);
      var announced = false;
      on('boosts:changed', (_) => announced = true);
      buyGemItem(state, 'trophy_polish_gem');
      expect(state['boosts']['trophyPolishUntil'], 1000 + trophyPolishMs);
      expect(state['boosts']['trophyPolishSeason'], isNull);
      expect(announced, isTrue);
    });

    test('and so cannot be bought twice inside one window', () {
      setClock(() => 1000);
      addTearDown(resetClock);
      final state = _state(gems: 40, seasonCount: 6);
      expect(buyGemItem(state, 'trophy_polish_gem').ok, isTrue);
      final second = buyGemItem(state, 'trophy_polish_gem');
      expect(second.ok, isFalse);
      expect(second.reason, 'already_held');
      expect(getGems(state), 32);
    });

    test('an unknown item is refused before any debit', () {
      final state = _state(gems: 50);
      expect(buyGemItem(state, 'nonsense').reason, 'unknown_item');
      expect(getGems(state), 50);
    });

    test('buying builds the branches a bare save is missing', () {
      final state = <String, dynamic>{'resources': {'gems': 20}};
      expect(buyGemItem(state, 'scout_voucher_gem').ok, isTrue);
      expect(state['shop']['freeScoutReady'], isTrue);
    });
  });

  group('the pricing rules', () {
    test('the gamble is strictly cheaper than a look pack', () {
      expect(getGemItem('scout_voucher_gem')!.cost, lessThan(packGemCost()));
    });

    test('a tank of energy is priced level with a permanent look pack', () {
      // Deliberate, and worth keeping in view: the catalogue used to enforce
      // the other ordering on the grounds that a consumable outranking a
      // cosmetic says a hat is worth less than a tank.
      expect(getGemItem('energy_refill')!.cost, packGemCost());
    });

    test('the pack price is flat across the catalogue', () {
      expect(packGemCost(), packGemCostValue);
    });
  });
}
