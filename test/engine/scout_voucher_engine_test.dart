/// The Guaranteed Scout, against the JS it was ported from.
///
/// Nothing here is random. What it pins is the RULE the whole item rests on: a
/// voucher may never guarantee a tier the player's own division cannot already
/// scout for coins, so what is buyable is DERIVED from the odds table rather
/// than tabulated. A port that hardcoded the ladder would look identical today
/// and quietly break the moment the odds are retuned.
///
/// The other half is the one-voucher rule, which lives in two files that cannot
/// import each other — this engine's [anyVoucherArmed] and the gem catalogue's
/// `scout_voucher_gem` — so both are checked against the same shop shapes here.
///
/// See `tool/dump_scout_voucher_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/engine/scout_voucher_engine.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/scout_voucher_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(String key) =>
    (_ref[key] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _section(String key) => _ref[key] as Map<String, dynamic>;

List<String> get _divIds => (_ref['divisionIds'] as List).cast<String>();

/// The JS reported a block as a snake-case string.
const _blockNames = {
  VoucherBlock.notOffered: 'not_offered',
  VoucherBlock.noPrice: 'no_price',
  VoucherBlock.alreadyHeld: 'already_held',
  VoucherBlock.insufficientGems: 'insufficient_gems',
};

Map<String, dynamic> _state({
  String division = 'regional_league',
  num gems = 20,
  Map<String, dynamic> shop = const {},
}) => {
  'progression': <String, dynamic>{'currentDivision': division},
  'resources': <String, dynamic>{'fanCoins': 0, 'gems': gems, 'trophies': 0},
  'shop': <String, dynamic>{...shop},
};

/// The shop shapes the reference was built against.
///
/// `floorInfinite` cannot ride in JSON, so it is rebuilt here — and it is the
/// case that matters most, since an infinite tier passes a naive `> 1`.
Map<String, dynamic> _shop(String label) => switch (label) {
  'empty' => const {},
  'freeScout' => const {'freeScoutReady': true},
  'freeScoutFalse' => const {'freeScoutReady': false},
  'floorArmed' => const {'scoutVoucherTier': 5},
  'floorOne' => const {'scoutVoucherTier': 1},
  'floorZero' => const {'scoutVoucherTier': 0},
  'floorNull' => const {'scoutVoucherTier': null},
  'floorFractional' => const {'scoutVoucherTier': 5.7},
  'floorInfinite' => {'scoutVoucherTier': double.infinity},
  'floorString' => const {'scoutVoucherTier': '5'},
  'both' => const {'scoutVoucherTier': 4, 'freeScoutReady': true},
  _ => throw ArgumentError(label),
};

/// The gem catalogue's half of the one-voucher rule.
bool _gemHeld(Map<String, dynamic> state) =>
    gemItems
        .firstWhere((i) => i.id == 'scout_voucher_gem')
        .heldWhen
        ?.call(state) ??
    false;

void main() {
  test('the ladder and the prices match the JS', () {
    expect(maxVoucherTier, _ref['maxVoucherTier']);
    expect(voucherTiers, _ref['voucherTiers']);
    final want = _section('voucherGemCost');
    expect(voucherGemCost.length, want.length);
    for (final entry in want.entries) {
      expect(
        voucherGemCost[int.parse(entry.key)],
        entry.value,
        reason: 'tier ${entry.key}',
      );
    }
  });

  test('parity — what each division offers', () {
    for (final entry in _section('tiersFor').entries) {
      expect(voucherTiersFor(entry.key), entry.value, reason: entry.key);
    }
    expect(voucherTiersFor(null), _ref['tiersForNull']);
  });

  test('parity — whether a floor is offered', () {
    for (final row in _rows('offered')) {
      expect(
        voucherOffered(row['divisionId'] as String, row['floor'] as int),
        row['offered'],
        reason: '${row['divisionId']} t${row['floor']}',
      );
    }
  });

  test('parity — which division unlocks a rung', () {
    for (final entry in _section('unlockDivision').entries) {
      expect(
        voucherUnlockDivision(int.parse(entry.key)),
        entry.value,
        reason: 'tier ${entry.key}',
      );
    }
  });

  test('parity — what a rung costs', () {
    for (final entry in _section('cost').entries) {
      expect(
        voucherCost(int.parse(entry.key)),
        entry.value,
        reason: 'tier ${entry.key}',
      );
    }
  });

  test('parity — the odds an ordinary scout clears the floor', () {
    for (final row in _rows('odds')) {
      expect(
        voucherOdds(row['divisionId'] as String, row['floor'] as int),
        row['odds'],
        reason: '${row['divisionId']} t${row['floor']}',
      );
    }
  });

  test('parity — what counts as armed, in both halves of the rule', () {
    // The engine and the gem catalogue cannot import each other, so this is the
    // only thing holding them to the same answer.
    for (final row in _rows('armed')) {
      final label = row['label'] as String;
      final state = _state(shop: _shop(label));
      expect(heldVoucherTier(state), row['held'], reason: '$label held');
      expect(anyVoucherArmed(state), row['armed'], reason: '$label armed');
      expect(_gemHeld(state), row['gemHeld'], reason: '$label gem');
      expect(
        _gemHeld(state),
        anyVoucherArmed(state),
        reason: '$label — the two halves must agree',
      );
    }
  });

  test('parity — a save with nothing in it', () {
    final noState = _section('armedNoState');
    expect(heldVoucherTier(null), noState['held']);
    expect(anyVoucherArmed(null), noState['armed']);

    final noShop = _section('armedNoShop');
    final state = <String, dynamic>{'progression': <String, dynamic>{}};
    expect(heldVoucherTier(state), noShop['held']);
    expect(anyVoucherArmed(state), noShop['armed']);
  });

  test('parity — why a voucher is refused', () {
    for (final row in _rows('blocked')) {
      final blocked = voucherBlocked(
        _state(
          division: row['division'] as String,
          gems: row['gems'] as num,
          shop: (row['shop'] as Map<String, dynamic>?) ?? const {},
        ),
        row['floor'] as int,
      );
      expect(
        blocked == null ? null : _blockNames[blocked],
        row['blocked'],
        reason: '${row['label']}',
      );
    }
    expect(
      voucherBlocked(null, 5) == null
          ? null
          : _blockNames[voucherBlocked(null, 5)],
      _ref['blockedNoState'],
    );
  });

  test('parity — buying one', () {
    for (final row in _rows('buy')) {
      final label = row['label'] as String;
      final state = _state(
        division: switch (label) {
          'cheapestRung' => 'amateur_cup',
          'refusedNotOffered' => 'sunday_league',
          _ => 'champions_cup',
        },
        gems: label == 'refusedTooPoor' ? 1 : 20,
        shop: label == 'refusedAlreadyArmed'
            ? const {'scoutVoucherTier': 2}
            : const {},
      );
      final result = buyScoutVoucher(state, row['floor'] as int);
      final want = row['result'] as Map<String, dynamic>;
      expect(result.ok, want['ok'], reason: '$label ok');
      expect(result.floor, want['floor'], reason: '$label floor');
      expect(result.cost, want['cost'], reason: '$label cost');
      expect(
        result.reason == null ? null : _blockNames[result.reason],
        want['reason'],
        reason: '$label reason',
      );
      expect(
        (state['resources'] as Map)['gems'],
        row['gems'],
        reason: '$label gems',
      );
      expect(state['shop'], row['shop'], reason: '$label shop');
    }
  });

  test('parity — a save with no shop branch still arms one', () {
    final want = _section('buyNoShopBranch');
    final state = <String, dynamic>{
      'progression': <String, dynamic>{'currentDivision': 'champions_cup'},
      'resources': <String, dynamic>{'gems': 20},
    };
    final result = buyScoutVoucher(state, 6);
    expect(result.ok, (want['result'] as Map)['ok']);
    expect(state['shop'], want['shop']);
    expect((state['resources'] as Map)['gems'], want['gems']);
  });

  test('parity — spending it', () {
    for (final row in _rows('consume')) {
      final label = row['label'] as String;
      final state = _state(
        shop: switch (label) {
          'armed' => const {'scoutVoucherTier': 7},
          'fractional' => const {'scoutVoucherTier': 7.9},
          'none' => const {},
          'tierOne' => const {'scoutVoucherTier': 1},
          'freeScoutOnly' => const {'freeScoutReady': true},
          _ => const {},
        },
      );
      expect(consumeScoutVoucher(state), row['floor'], reason: '$label floor');
      expect(state['shop'], row['shop'], reason: '$label shop');
      expect(
        anyVoucherArmed(state),
        row['armedAfter'],
        reason: '$label armedAfter',
      );
    }
  });

  test('parity — buy, spend, buy again', () {
    final want = _section('roundTrip');
    final state = _state(division: 'champions_cup');
    final first = buyScoutVoucher(state, 4);
    expect(first.ok, (want['first'] as Map)['ok']);
    final blocked = voucherBlocked(state, 6);
    expect(
      blocked == null ? null : _blockNames[blocked],
      want['blockedWhileArmed'],
    );
    expect(consumeScoutVoucher(state), want['spent']);
    final second = buyScoutVoucher(state, 6);
    expect(second.ok, (want['second'] as Map)['ok']);
    expect((state['resources'] as Map)['gems'], want['gems']);
    expect(state['shop'], want['shop']);
  });

  test('parity — exactly one new rung per promotion', () {
    // What stops the Shop growing two chips on one row, and the reason the
    // ladder can be seven rungs with one lighting up per division.
    for (final row in _rows('ladder')) {
      final divisionId = row['divisionId'] as String;
      expect(voucherTiersFor(divisionId), row['tiers'], reason: divisionId);
      expect((row['newRungs'] as List).length, 1, reason: divisionId);
    }
    expect(_rows('ladder').length, _divIds.length);
  });

  test('a voucher can never promise more than the division already scouts', () {
    // The rule the whole item rests on. Derived from the odds table, so this
    // holds without anything here knowing what the table says.
    for (final divisionId in _divIds) {
      for (final floor in voucherTiersFor(divisionId)) {
        expect(
          voucherOdds(divisionId, floor),
          greaterThan(0),
          reason: '$divisionId t$floor',
        );
      }
      expect(voucherTiersFor(divisionId), isNot(contains(9)));
      expect(voucherTiersFor(divisionId), isNot(contains(1)));
    }
  });

  // ── The inventory, which is the port's own and has no JS to check against ──
  //
  // Everything above compares against `../merge-empire-fc`. Nothing below can:
  // vouchers being COLLECTABLE is a divergence this port made deliberately, so
  // these are ordinary tests of ordinary behaviour.

  group('the inventory', () {
    Map<String, dynamic> inv(List<int> held) =>
        _state(division: 'champions_cup', shop: {'scoutVouchers': [...held]});

    test('a save with no key at all holds nothing', () {
      // `createDefaultState` cannot declare `scoutVouchers` without failing the
      // JS shape parity, so this is what every fresh save actually looks like.
      expect(voucherInventory(_state()), isEmpty);
      expect(voucherInventory(null), isEmpty);
      expect(hasVouchers(_state()), isFalse);
    });

    test('reads back dearest first, duplicates kept', () {
      expect(voucherInventory(inv([3, 8, 3, 1])), [8, 3, 3, 1]);
      expect(voucherCount(inv([3, 8, 3, 1]), 3), 2);
      expect(voucherCount(inv([3, 8, 3, 1]), 5), 0);
    });

    test('junk in the list is dropped rather than thrown', () {
      // Same exposure as the scalar: a hand-edited or cloud-synced save.
      final state = _state(
        shop: {
          'scoutVouchers': [5, 0, 9, 'four', null, 2.7, double.infinity],
        },
      );
      // 9 is above `maxVoucherTier` and 0 below the token, so both go; 2.7
      // floors to 2, which is a real rung.
      expect(voucherInventory(state), [5, 2]);
    });

    test('granting builds the list a fresh save has not got', () {
      final state = _state();
      grantVoucher(state, 6);
      grantVoucher(state, 6);
      expect((state['shop'] as Map)['scoutVouchers'], [6, 6]);
    });

    test('granting builds the shop branch too', () {
      final state = <String, dynamic>{};
      grantVoucher(state, anyCardVoucher);
      expect((state['shop'] as Map)['scoutVouchers'], [1]);
    });

    test('an out-of-range grant is refused, not clamped', () {
      final state = _state();
      grantVoucher(state, 0);
      grantVoucher(state, 9);
      expect(voucherInventory(state), isEmpty);
    });

    test('taking removes ONE of that floor and reports it', () {
      final state = inv([5, 5, 8]);
      expect(takeVoucher(state, 5), 5);
      expect(voucherInventory(state), [8, 5]);
      expect(takeVoucher(state, 5), 5);
      expect(takeVoucher(state, 5), isNull);
      expect(voucherInventory(state), [8]);
    });

    test('taking from a save with no inventory is null, not a crash', () {
      expect(takeVoucher(_state(), 5), isNull);
    });

    test('THE TOKEN REACHES THE DRAW AS NO FLOOR AT ALL', () {
      // The one failure nothing else would catch. `buildScoutDrawPool` filters
      // `tier >= minTier && tier <= 8`, so ANY non-null floor — 1 included —
      // cuts tier 9 out of the pool. The 🎲 rung is the only voucher that can
      // hand over a Football Icon, and passing 1 through as a floor would
      // delete that silently: no test fails, no screen changes, and the
      // cheapest thing on the shelf quietly stops selling what it advertises.
      expect(drawFloorFor(anyCardVoucher), isNull);
      for (final floor in voucherTiers) {
        expect(drawFloorFor(floor), floor, reason: 't$floor');
      }
    });
  });

  group('buying into the inventory', () {
    test('debits the gems and banks the floor', () {
      final state = _state(division: 'champions_cup', gems: 20);
      final result = purchaseScoutVoucher(state, 6);
      expect(result.ok, isTrue);
      expect(result.cost, 6);
      expect(getGems(state), 14);
      expect(voucherInventory(state), [6]);
    });

    test('AND AGAIN, which the one-at-a-time rule used to forbid', () {
      // The whole point. `voucherBlocked` still answers `alreadyHeld` for the
      // JS's scalar shape — that is asserted above — but nothing in the game
      // writes that scalar any more, so the shelf never sees it.
      final state = _state(division: 'champions_cup', gems: 20);
      expect(purchaseScoutVoucher(state, 6).ok, isTrue);
      expect(purchaseScoutVoucher(state, 6).ok, isTrue);
      expect(purchaseScoutVoucher(state, 3).ok, isTrue);
      expect(voucherInventory(state), [6, 6, 3]);
      expect(getGems(state), 5);
    });

    test('still refuses a rung this division cannot scout', () {
      final state = _state(division: 'sunday_league', gems: 20);
      final result = purchaseScoutVoucher(state, 8);
      expect(result.reason, VoucherBlock.notOffered);
      expect(voucherInventory(state), isEmpty);
      expect(getGems(state), 20);
    });

    test('still refuses when the gems are not there', () {
      final state = _state(division: 'champions_cup', gems: 1);
      expect(
        purchaseScoutVoucher(state, 8).reason,
        VoucherBlock.insufficientGems,
      );
      expect(voucherInventory(state), isEmpty);
    });

    test('holding a stack never blocks a purchase', () {
      final state = _state(
        division: 'champions_cup',
        gems: 20,
        shop: {
          'scoutVouchers': [8, 8, 8],
        },
      );
      expect(voucherPurchaseBlocked(state, 8), isNull);
      expect(purchaseScoutVoucher(state, 8).ok, isTrue);
    });
  });
}
