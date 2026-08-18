/// The daily login reward, against the JS it was ported from.
///
/// Everything here turns on a LOCAL day key — midnight to midnight in the
/// player's own timezone — so the cases are built from local wall-clock
/// components rather than epoch stamps, and both runtimes construct their own
/// instants from the same calendar date. Noon, so a daylight-saving shift cannot
/// move a case onto the day before.
///
/// The interesting arithmetic is the streak: it continues only when the last
/// claim was YESTERDAY's key, restarts at 1 otherwise, and the cycle day wraps 7
/// back to 1 independently of it. Those two counters are easy to conflate and
/// they are not the same number — a repaired streak of forty can sit on cycle
/// day 3.
///
/// See `tool/dump_daily_reward_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/daily_reward_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/daily_reward_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

final Map<String, dynamic> _questRef =
    jsonDecode(
          File('test/fixtures/quest_engine_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(String key) =>
    (_ref[key] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _section(String key) => _ref[key] as Map<String, dynamic>;

const int _day = 24 * 60 * 60 * 1000;

/// Local noon on the reference's calendar date, rebuilt here rather than shipped
/// as an epoch stamp.
int _at({int? d, int? h}) {
  final a = _ref['at'] as Map<String, dynamic>;
  return DateTime(
    a['y'] as int,
    a['m'] as int,
    d ?? a['d'] as int,
    h ?? a['h'] as int,
  ).millisecondsSinceEpoch;
}

String _key(int ts) => dateString(ts);

/// A `dailyReward` branch, matching the dump script's builder.
Map<String, dynamic> _dr({
  int cycleDay = 0,
  String? lastClaimDayKey,
  int streak = 0,
  int longestStreak = 0,
  int totalClaims = 0,
  String? lastAutoPopupDayKey,
}) => {
  'cycleDay': cycleDay,
  'lastClaimDayKey': lastClaimDayKey,
  'streak': streak,
  'longestStreak': longestStreak,
  'totalClaims': totalClaims,
  'lastAutoPopupDayKey': lastAutoPopupDayKey,
};

Map<String, dynamic> _state({
  num coins = 0,
  num gems = 0,
  String division = 'regional_league',
  bool hardMode = false,
  Map<String, dynamic>? dailyReward,
  Map<String, dynamic>? miniGames,
  int mediaTier = 0,
}) {
  final s = jsonDecode(jsonEncode(_questRef['state'])) as Map<String, dynamic>;
  (s['resources'] as Map)['fanCoins'] = coins;
  (s['resources'] as Map)['gems'] = gems;
  s['energy'] = <String, dynamic>{'current': 3, 'lastRegenAt': 0};
  s['settings'] = <String, dynamic>{
    ...?(s['settings'] as Map<String, dynamic>?),
    'hardMode': hardMode,
  };
  (s['progression'] as Map)['currentDivision'] = division;
  s['clubAssets'] = <String, dynamic>{
    ...?(s['clubAssets'] as Map<String, dynamic>?),
    'MEDIA': <String, dynamic>{
      'owned': mediaTier > 0,
      'tier': mediaTier,
      'invested': 0,
      'tapCount': 0,
    },
  };
  if (dailyReward != null) s['dailyReward'] = dailyReward;
  if (miniGames != null) s['miniGames'] = miniGames;
  return s;
}

/// Only what a claim actually writes.
Map<String, dynamic> _digest(Map<String, dynamic> s) {
  final cells = (s['grid'] as Map)['cells'] as List;
  return {
    'dailyReward': s['dailyReward'],
    'fanCoins': (s['resources'] as Map)['fanCoins'],
    'gems': (s['resources'] as Map)['gems'],
    'energy': s['energy'],
    'shop': s['shop'],
    'cellEnergies': [
      for (final c in cells) c == null ? null : (c as Map)['energy'],
    ],
    'injured': [
      for (final c in cells) c == null ? null : (c as Map)['injured'] == true,
    ],
  };
}

Map<String, dynamic> _statusAsJson(DailyRewardStatus s) => {
  'claimedToday': s.claimedToday,
  'day': s.day,
  'streak': s.streak,
  'broken': s.broken,
  'trainedBonus': s.trainedBonus,
  'reward': s.reward == null ? null : _previewAsJson(s.reward!),
};

Map<String, dynamic> _previewAsJson(DailyRewardPreview p) => {
  'day': p.day,
  'coins': p.coins,
  'energy': p.energy,
  'freeScout': p.freeScout,
  'healOne': p.healOne,
  'gems': p.gems,
};

Map<String, dynamic> _claimAsJson(DailyClaim c) => c.ok
    ? {
        'ok': true,
        'day': c.day,
        'streak': c.streak,
        'coins': c.coins,
        'energy': c.energy,
        'teamEnergyPct': c.teamEnergyPct,
        'gems': c.gems,
        'freeScout': c.freeScout,
        'healOne': c.healOne,
        'healedCount': c.healedCount,
        'doubled': c.doubled,
        'trainedBonus': c.trainedBonus,
      }
    : {'ok': false, 'reason': c.reason};

/// The `dailyReward` branch a status row was built with.
Map<String, dynamic>? _statusBranch(String label) => switch (label) {
  'neverClaimed' || 'freshBranch' => null,
  'claimedToday' => _dr(
    cycleDay: 3,
    lastClaimDayKey: _key(_at()),
    streak: 3,
    totalClaims: 3,
  ),
  'claimedYesterday' => _dr(
    cycleDay: 3,
    lastClaimDayKey: _key(_at() - _day),
    streak: 3,
    totalClaims: 3,
  ),
  'wrapsPastSeven' => _dr(
    cycleDay: 7,
    lastClaimDayKey: _key(_at() - _day),
    streak: 7,
    totalClaims: 7,
  ),
  'brokenStreak' => _dr(
    cycleDay: 4,
    lastClaimDayKey: _key(_at() - 3 * _day),
    streak: 4,
    totalClaims: 4,
  ),
  'gapWithNoStreak' => _dr(
    cycleDay: 2,
    lastClaimDayKey: _key(_at() - 3 * _day),
    totalClaims: 2,
  ),
  _ => null,
};

Map<String, dynamic>? _statusMiniGames(String label) => switch (label) {
  'trainedToday' => {'trainingLastPlayed': _at(h: 9)},
  'trainedYesterday' => {'penaltyLastPlayed': _at() - _day},
  'trainedTwoDaysAgo' => {'penaltyLastPlayed': _at() - 2 * _day},
  'neverTrained' => {'penaltyLastPlayed': 0, 'trainingLastPlayed': 0},
  'whackDoesNotCount' => {
    'whackLastPlayed': _at(h: 9),
    'bootRoomLastPlayed': _at(h: 9),
  },
  _ => null,
};

/// The branch a claim row was seeded with.
Map<String, dynamic>? _claimBranch(String label) {
  if (label.startsWith('day') && label.length >= 4) {
    final day = int.tryParse(label.substring(3, 4));
    if (day != null) {
      if (day == 1) return label == 'day1Doubled' ? null : _dr();
      return _dr(
        cycleDay: day - 1,
        lastClaimDayKey: _key(_at() - _day),
        streak: day - 1,
        longestStreak: day - 1,
        totalClaims: day - 1,
      );
    }
  }
  return switch (label) {
    'hardModeEnergy' => _dr(
      cycleDay: 1,
      lastClaimDayKey: _key(_at() - _day),
      streak: 1,
      longestStreak: 1,
      totalClaims: 1,
    ),
    'brokenRestarts' => _dr(
      cycleDay: 5,
      lastClaimDayKey: _key(_at() - 4 * _day),
      streak: 9,
      longestStreak: 12,
      totalClaims: 9,
    ),
    _ => null,
  };
}

Map<String, dynamic>? _claimMiniGames(String label) =>
    label.startsWith('trainedBonus') ? {'trainingLastPlayed': _at(h: 9)} : null;

void main() {
  setUp(() => setClock(() => _at()));
  tearDown(() {
    resetClock();
    clearBus();
  });

  test('the calendar matches the JS', () {
    expect(cycleDays, _ref['cycleDays']);
    expect(trainedBonusMult, _ref['trainedBonusMult']);
    final want = _section('calendar');
    expect(dailyRewards.length, want.length);
    for (final entry in want.entries) {
      final def = dailyRewards[int.parse(entry.key)]!;
      final w = entry.value as Map<String, dynamic>;
      expect(def.coinsMult, w['coinsMult'] ?? 0, reason: 'day ${entry.key}');
      expect(def.energy, w['energy'] ?? 0, reason: 'day ${entry.key}');
      expect(def.gems, w['gems'] ?? 0, reason: 'day ${entry.key}');
      expect(
        def.freeScout,
        w['freeScout'] ?? false,
        reason: 'day ${entry.key}',
      );
      expect(def.healOne, w['healOne'] ?? false, reason: 'day ${entry.key}');
    }
  });

  test('parity — what a day is worth', () {
    for (final row in _rows('preview')) {
      final preview = getDailyRewardPreview(
        _state(
          division: row['division'] as String,
          mediaTier: row['mediaTier'] as int,
        ),
        row['day'] as int,
      );
      final reason =
          'day ${row['day']} ${row['division']} media ${row['mediaTier']}';
      if (row['preview'] == null) {
        expect(preview, isNull, reason: reason);
      } else {
        expect(_previewAsJson(preview!), row['preview'], reason: reason);
      }
    }
  });

  test('parity — where the player stands', () {
    for (final row in _rows('status')) {
      final label = row['label'] as String;
      final state = _state(
        dailyReward: _statusBranch(label),
        miniGames: _statusMiniGames(label),
      );
      if (label == 'freshBranch') state.remove('dailyReward');
      final status = getDailyRewardStatus(state, _at());
      expect(_statusAsJson(status), row['status'], reason: label);
      expect(state['dailyReward'], row['branchAfter'], reason: '$label branch');
      expect(
        canRepairStreak(state, _at()),
        row['canRepair'],
        reason: '$label canRepair',
      );
    }
  });

  test('the status reads the clock when it is not given one', () {
    expect(getDailyRewardStatus(_state()).day, 1);
    expect(canRepairStreak(_state()), false);
    expect(getDailyStreak(_state(dailyReward: _dr(streak: 4))), 4);
  });

  test('parity — repairing a broken streak', () {
    for (final row in _rows('repair')) {
      final label = row['label'] as String;
      final branch = switch (label) {
        'broken' => _dr(
          cycleDay: 4,
          lastClaimDayKey: _key(_at() - 3 * _day),
          streak: 4,
          totalClaims: 4,
        ),
        'notBroken' => _dr(
          cycleDay: 4,
          lastClaimDayKey: _key(_at() - _day),
          streak: 4,
          totalClaims: 4,
        ),
        'neverClaimed' => _dr(),
        'brokenAtDayZero' => _dr(
          lastClaimDayKey: _key(_at() - 3 * _day),
          streak: 2,
        ),
        _ => _dr(),
      };
      final state = _state(dailyReward: branch);
      final result = repairStreak(state, _at());
      final want = row['result'] as Map<String, dynamic>;
      expect(result.ok, want['ok'], reason: '$label ok');
      expect(result.reason, want['reason'], reason: '$label reason');
      expect(result.streak, want['streak'], reason: '$label streak');
      expect(state['dailyReward'], row['branchAfter'], reason: '$label branch');
      expect(
        _statusAsJson(getDailyRewardStatus(state, _at())),
        row['statusAfter'],
        reason: '$label status',
      );
    }
  });

  test('parity — claiming', () {
    for (final row in _rows('claim')) {
      final label = row['label'] as String;
      final state = _state(
        coins: 1000,
        gems: 5,
        dailyReward: _claimBranch(label),
        miniGames: _claimMiniGames(label),
        hardMode: row['hardMode'] as bool,
        division: row['division'] as String,
      );
      final claim = claimDailyReward(
        state,
        doubled: row['doubled'] as bool,
        ts: _at(),
      );
      expect(_claimAsJson(claim), row['result'], reason: label);
      expect(_digest(state), row['state'], reason: '$label state');
    }
  });

  test('parity — a repaired streak carries the cycle on', () {
    // The streak and the cycle day are different numbers: a repaired streak of
    // nine sits on cycle day 6, not day 1.
    final want = _section('claimAfterRepair');
    final state = _state(
      dailyReward: _dr(
        cycleDay: 5,
        lastClaimDayKey: _key(_at() - 4 * _day),
        streak: 9,
        longestStreak: 12,
        totalClaims: 9,
      ),
    );
    final repair = repairStreak(state, _at());
    expect(repair.ok, (want['repair'] as Map)['ok']);
    final claim = claimDailyReward(state, ts: _at());
    expect(_claimAsJson(claim), want['result']);
    expect(_digest(state), want['state']);
  });

  test('parity — the second claim of the day gets nothing', () {
    final want = _section('claimTwice');
    final state = _state();
    final first = claimDailyReward(state, ts: _at());
    final second = claimDailyReward(state, ts: _at(h: 22));
    expect(_claimAsJson(first), want['first']);
    expect(_claimAsJson(second), want['second']);
    expect(_digest(state), want['state']);
  });

  test('parity — nine days in a row, cycle and streak apart', () {
    final want = _section('wholeWeek');
    final state = _state(coins: 0, gems: 0);
    final days = <Map<String, dynamic>>[];
    for (var i = 0; i < 9; i++) {
      final claim = claimDailyReward(state, ts: _at() + i * _day);
      days.add({
        'i': i,
        'day': claim.day,
        'streak': claim.streak,
        'coins': claim.coins,
        'gems': claim.gems,
        'energy': claim.energy,
      });
    }
    expect(days, want['days']);
    expect(state['dailyReward'], want['branch']);
    expect((state['resources'] as Map)['fanCoins'], want['fanCoins']);
    expect((state['resources'] as Map)['gems'], want['gems']);
  });

  group('parity — the two calendar entries nothing currently uses', () {
    // Still supported end to end, so a day can pick either back up with no new
    // plumbing. Exercised by swapping day 4 out, exactly as the dump does.
    late DailyReward original;

    setUp(() {
      original = dailyRewards[4]!;
      dailyRewards[4] = (
        coinsMult: 1,
        energy: 0,
        gems: 0,
        freeScout: true,
        healOne: true,
      );
    });
    tearDown(() => dailyRewards[4] = original);

    List<dynamic> injuredCells() {
      final cells =
          jsonDecode(
                jsonEncode(
                  ((_questRef['state'] as Map)['grid'] as Map)['cells'],
                ),
              )
              as List;
      for (var i = 0; i < 3; i++) {
        (cells[i] as Map)
          ..['injured'] = true
          ..['injuredAt'] = 1
          ..['injuryDurationMs'] = 100;
      }
      return cells;
    }

    Map<String, dynamic> seeded() => _state(
      dailyReward: _dr(
        cycleDay: 3,
        lastClaimDayKey: _key(_at() - _day),
        streak: 3,
        longestStreak: 3,
        totalClaims: 3,
      ),
    );

    test('the preview reports them', () {
      expect(
        _previewAsJson(getDailyRewardPreview(_state(), 4)!),
        _section('unusedRewards')['preview'],
      );
    });

    test('one sponge heals one, doubled heals two', () {
      for (final label in ['single', 'doubled']) {
        final want = _section('unusedRewards')[label] as Map<String, dynamic>;
        final state = seeded();
        (state['grid'] as Map)['cells'] = injuredCells();
        final claim = claimDailyReward(
          state,
          doubled: label == 'doubled',
          ts: _at(),
        );
        expect(_claimAsJson(claim), want['result'], reason: label);
        expect(_digest(state), want['state'], reason: '$label state');
      }
    });

    test('a sponge with nobody to heal heals nobody', () {
      final want =
          _section('unusedRewards')['nobodyInjured'] as Map<String, dynamic>;
      final state = seeded();
      final claim = claimDailyReward(state, ts: _at());
      expect(_claimAsJson(claim), want['result']);
      expect(_digest(state), want['state']);
    });
  });

  test('parity — the once-a-day popup gate', () {
    final want = _section('popup');
    final state = _state();
    expect(shouldAutoShowPopup(state, _at()), want['first']);
    expect(shouldAutoShowPopup(state, _at(h: 20)), want['second']);
    expect(shouldAutoShowPopup(state, _at(d: 19)), want['tomorrow']);
    expect(state['dailyReward'], want['branch']);

    final claimed = _state(
      dailyReward: _dr(
        cycleDay: 1,
        lastClaimDayKey: _key(_at()),
        streak: 1,
        totalClaims: 1,
      ),
    );
    expect(shouldAutoShowPopup(claimed, _at()), want['afterClaim']);
    expect(claimed['dailyReward'], want['claimedBranch']);
  });

  test('parity — the HUD streak chip', () {
    for (final row in _rows('streakChip')) {
      final got = switch (row['label']) {
        'none' => getDailyStreak(_state()),
        'running' => getDailyStreak(_state(dailyReward: _dr(streak: 12))),
        'nullState' => getDailyStreak(null),
        _ => getDailyStreak(<String, dynamic>{}),
      };
      expect(got, row['streak'], reason: '${row['label']}');
    }
  });

  group('what it announces', () {
    test('a claim announces the balance, the pips and itself', () {
      final events = <String, Object?>{};
      for (final name in [
        'coins:updated',
        'energy:updated',
        'dailyreward:claimed',
      ]) {
        on(name, (v) => events[name] = v);
      }
      final state = _state(
        coins: 1000,
        dailyReward: _dr(
          cycleDay: 1,
          lastClaimDayKey: _key(_at() - _day),
          streak: 1,
          totalClaims: 1,
        ),
      );
      final claim = claimDailyReward(state, ts: _at());
      expect(events['coins:updated'], (state['resources'] as Map)['fanCoins']);
      expect(events['energy:updated'], (state['energy'] as Map)['current']);
      expect(events['dailyreward:claimed'], claim);
    });

    test('Pro mode tops up fitness instead, and says nothing about pips', () {
      // There is no pip pool in Pro, so an `energy:updated` there would be
      // announcing a number nothing displays.
      Object? pips;
      on('energy:updated', (v) => pips = v);
      final state = _state(
        coins: 1000,
        hardMode: true,
        dailyReward: _dr(
          cycleDay: 1,
          lastClaimDayKey: _key(_at() - _day),
          streak: 1,
          totalClaims: 1,
        ),
      );
      final claim = claimDailyReward(state, ts: _at());
      expect(claim.teamEnergyPct, greaterThan(0));
      expect(pips, isNull);
      expect((state['energy'] as Map)['current'], 3);
    });
  });

  test('a save missing every branch still claims', () {
    // And it reads the clock rather than being handed one, which is the path the
    // app itself takes.
    final state =
        _state(
            dailyReward: _dr(
              cycleDay: 1,
              lastClaimDayKey: _key(_at() - _day),
              streak: 1,
              totalClaims: 1,
            ),
          )
          ..remove('resources')
          ..remove('energy');
    final claim = claimDailyReward(state);
    expect(claim.ok, true);
    expect(claim.day, 2); // the energy day
    expect((state['resources'] as Map)['fanCoins'], claim.coins);
    expect((state['energy'] as Map)['current'], claim.energy);
    expect((state['energy'] as Map)['lastRegenAt'], _at());
  });

  test('repair and the popup gate read the clock too', () {
    final state = _state(
      dailyReward: _dr(
        cycleDay: 4,
        lastClaimDayKey: _key(_at() - 3 * _day),
        streak: 4,
        totalClaims: 4,
      ),
    );
    expect(repairStreak(state).ok, true);
    expect(shouldAutoShowPopup(_state()), true);
  });

  test('what lands in the save serialises', () {
    final state = _state(coins: 1000, gems: 5);
    for (var i = 0; i < 8; i++) {
      claimDailyReward(state, ts: _at() + i * _day);
    }
    expect(() => jsonEncode(state), returnsNormally);
    expect((state['resources'] as Map)['fanCoins'], isA<int>());
  });
}
