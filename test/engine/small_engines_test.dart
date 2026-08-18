/// Three small engines that share one fixture because none of them is big
/// enough to earn its own: the rewarded-ad frequency gate, the shirt badge, and
/// the look-pack shop tile.
///
/// What each is worth pinning FOR is different. The ad gate is a rolling window
/// and a countdown that has to round the right way — a label reading 0:00 while
/// the gate is still shut is a button that lies. The badge is an ordering:
/// newest for the auto-equip, oldest-first for the picker, off the same list.
/// And the look tile is a deliberate simplification of an older design, so the
/// thing to pin is what it no longer does.
///
/// See `tool/dump_small_engines_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/engine/ad_gate_engine.dart';
import 'package:merge_empire_fc/engine/badge_engine.dart';
import 'package:merge_empire_fc/engine/look_pack_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/time.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/small_engines_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

Map<String, dynamic> _section(String key) => _ref[key] as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(Map<String, dynamic> section) =>
    (section['rows'] as List).cast<Map<String, dynamic>>();

const int _min = 60 * 1000;

void main() {
  final adGate = _section('adGate');
  final now = adGate['now'] as int;

  setUp(() => setClock(() => now));
  tearDown(() {
    resetClock();
    clearBus();
  });

  group('the ad gate', () {
    /// The save shapes the reference was built against.
    Map<String, dynamic>? state(String label) => switch (label) {
      'none' => <String, dynamic>{},
      'noAdsBranch' => null,
      'emptyList' => {
        'ads': {'packUnlocks': <dynamic>[]},
      },
      'notAList' => {
        'ads': {'packUnlocks': 'nonsense'},
      },
      'oneRecent' => {
        'ads': {
          'packUnlocks': [now - _min],
        },
      },
      'twoRecent' => {
        'ads': {
          'packUnlocks': [now - 2 * _min, now - _min],
        },
      },
      'full' => {
        'ads': {
          'packUnlocks': [now - 3 * _min, now - 2 * _min, now - _min],
        },
      },
      'unsorted' => {
        'ads': {
          'packUnlocks': [now - _min, now - 4 * _min, now - 2 * _min],
        },
      },
      'oneAgedOut' => {
        'ads': {
          'packUnlocks': [now - 6 * _min, now - 2 * _min, now - _min],
        },
      },
      'allAgedOut' => {
        'ads': {
          'packUnlocks': [now - 9 * _min, now - 8 * _min, now - 7 * _min],
        },
      },
      'exactlyAtTheEdge' => {
        'ads': {
          'packUnlocks': [now - adPackWindowMs, now - _min, now - 2 * _min],
        },
      },
      'rubbishStamps' => {
        'ads': {
          'packUnlocks': [
            null,
            'soon',
            double.nan,
            double.infinity,
            now - _min,
          ],
        },
      },
      _ => throw ArgumentError(label),
    };

    test('the cap matches the AdMob setting', () {
      expect(adPackLimit, adGate['limit']);
      expect(adPackWindowMs, adGate['windowMs']);
    });

    test('parity — what the window holds, and what it allows', () {
      for (final row in _rows(adGate)) {
        final label = row['label'] as String;
        final s = state(label);
        expect(recentPackAds(s, now), row['recent'], reason: '$label recent');
        expect(
          packAdsRemaining(s, now),
          row['remaining'],
          reason: '$label remaining',
        );
        expect(
          canWatchPackAd(s, now),
          row['canWatch'],
          reason: '$label canWatch',
        );
        expect(msUntilPackAd(s, now), row['msUntil'], reason: '$label msUntil');
      }
    });

    test('parity — recording a video that paid out', () {
      final s = <String, dynamic>{};
      final want = (adGate['record'] as List).cast<Map<String, dynamic>>();
      for (var i = 0; i < want.length; i++) {
        final at = now + i * _min;
        recordPackAd(s, at);
        expect(s['ads'], want[i]['ads'], reason: 'after $i');
        expect(
          packAdsRemaining(s, at),
          want[i]['remaining'],
          reason: 'remaining after $i',
        );
        expect(
          msUntilPackAd(s, at),
          want[i]['msUntil'],
          reason: 'wait after $i',
        );
      }
    });

    test('a null state is a no-op rather than a throw', () {
      expect(() => recordPackAd(null, now), returnsNormally);
      expect(adGate['recordNullState'], true);
    });

    test('parity — the countdown label rounds up', () {
      // A label reading 0:00 while the gate is still shut is a button that lies.
      for (final row
          in (adGate['format'] as List).cast<Map<String, dynamic>>()) {
        expect(
          formatAdWait(row['ms'] as num),
          row['label'],
          reason: '${row['ms']}ms',
        );
      }
    });

    test('the clock is read when it is not given one', () {
      final s = <String, dynamic>{};
      recordPackAd(s);
      expect(recentPackAds(s), [now]);
      expect(packAdsRemaining(s), adPackLimit - 1);
      expect(canWatchPackAd(s), isTrue);
      expect(msUntilPackAd(s), 0);
    });
  });

  group('the badge', () {
    Map<String, dynamic> ach(String id, int? unlockedAt) => {
      'id': id,
      'unlockedAt': unlockedAt,
      'count': 1,
    };

    Map<String, dynamic> state(String label) => switch (label) {
      'fresh' => <String, dynamic>{},
      'noAchievements' => {
        'progression': <String, dynamic>{'achievements': <dynamic>[]},
      },
      'three' => {
        'progression': <String, dynamic>{
          'achievements': [
            ach('first_merge', 3000),
            ach('first_win', 1000),
            ach('coins_1k', 2000),
          ],
        },
      },
      'tied' => {
        'progression': <String, dynamic>{
          'achievements': [ach('first_merge', 1000), ach('first_win', 1000)],
        },
      },
      'unstamped' => {
        'progression': <String, dynamic>{
          'achievements': [
            // No stamp AT ALL, which is what an older save has — not a null one.
            {'id': 'first_merge', 'count': 1},
            ach('first_win', 5000),
          ],
        },
      },
      'unknownId' => {
        'progression': <String, dynamic>{
          'achievements': [
            ach('not_an_achievement', 9000),
            ach('first_win', 1000),
          ],
        },
      },
      'alreadyChosen' => {
        'progression': <String, dynamic>{
          'equippedBadgeId': 'first_win',
          'badgeManuallySet': true,
          'achievements': [ach('first_merge', 3000), ach('first_win', 1000)],
        },
      },
      _ => throw ArgumentError(label),
    };

    final badge = _section('badge');

    test('the default badge id matches the JS', () {
      expect(defaultBadgeId, badge['defaultId']);
    });

    test('parity — the newest, the choices, and what auto-equip does', () {
      for (final row in _rows(badge)) {
        final label = row['label'] as String;
        expect(
          getEquippedBadgeId(state(label)),
          row['equippedBefore'],
          reason: '$label before',
        );
        expect(
          getLatestUnlockedAchievement(state(label))?.id,
          row['latest'],
          reason: '$label latest',
        );
        expect(
          [for (final a in getBadgeChoices(state(label))) a.id],
          row['choices'],
          reason: '$label choices',
        );

        final s = state(label);
        expect(
          autoEquipLatestBadge(s),
          row['autoEquipChanged'],
          reason: '$label changed',
        );
        expect(
          getEquippedBadgeId(s),
          row['equippedAfter'],
          reason: '$label after',
        );
        expect(s['progression'], row['progression'], reason: '$label branch');
      }
    });

    test('parity — auto-equipping twice changes nothing the second time', () {
      final want = badge['autoTwice'] as Map<String, dynamic>;
      final s = state('three');
      expect(autoEquipLatestBadge(s), want['first']);
      expect(autoEquipLatestBadge(s), want['second']);
      expect(getEquippedBadgeId(s), want['equipped']);
    });

    test('parity — equipping one by hand', () {
      final want = (badge['setEquipped'] as List).cast<Map<String, dynamic>>();
      for (final row in want) {
        final label = row['label'] as String;
        final s = label == 'onABareSave' ? <String, dynamic>{} : state('three');
        expect(
          isValidBadgeId(
            label == 'onABareSave' ? <String, dynamic>{} : state('three'),
            row['badgeId'] as String,
          ),
          row['valid'],
          reason: '$label valid',
        );
        expect(
          setEquippedBadge(s, row['badgeId'] as String),
          row['ok'],
          reason: '$label ok',
        );
        expect(s['progression'], row['progression'], reason: '$label branch');
        // Once set by hand, the auto-equip stops tracking.
        expect(
          autoEquipLatestBadge(s),
          row['autoAfter'],
          reason: '$label autoAfter',
        );
      }
      expect(setEquippedBadge(null, 'first_win'), badge['setOnNullState']);
    });

    test('equipping announces it', () {
      Object? announced;
      on('badge:equipped', (v) => announced = v);
      final s = state('three');
      expect(setEquippedBadge(s, 'first_win'), isTrue);
      expect(announced, 'first_win');

      announced = null;
      final auto = state('three');
      expect(autoEquipLatestBadge(auto), isTrue);
      expect(announced, 'first_merge');
    });
  });

  group('the look-pack tile', () {
    final lookPack = _section('lookPack');

    test('the catalogue is the one the JS shipped', () {
      expect([for (final p in lookPacks) p.id], lookPack['packIds']);
    });

    test('parity — what a tile offers', () {
      for (final row in _rows(lookPack)) {
        final packId = row['packId'] as String;
        final pack = getLookPack(packId);
        final s = switch (row['label']) {
          'packOwned' => {
            'club': {
              'lookPacks': [packId],
            },
          },
          'oneItem' => {
            'club': {
              'lookItems': pack == null ? <String>[] : [pack.items.first],
            },
          },
          'everyItem' => {
            'club': {
              'lookItems': pack == null ? <String>[] : [...pack.items],
            },
          },
          _ => <String, dynamic>{},
        };
        final tile = lookTileState(s, packId);
        final want = row['tile'] as Map<String, dynamic>?;
        final reason = '$packId ${row['label']}';
        if (want == null) {
          expect(tile, isNull, reason: reason);
          continue;
        }
        expect(tile!.status, want['status'], reason: '$reason status');
        expect(tile.waitMs, want['waitMs'], reason: '$reason waitMs');
        expect(tile.cost, want['cost'], reason: '$reason cost');
        expect(tile.owned, want['owned'], reason: '$reason owned');
        expect(tile.total, want['total'], reason: '$reason total');
      }
      expect(
        lookTileState(
          null,
          (lookPack['packIds'] as List).first as String,
        )?.status,
        (lookPack['nullState'] as Map)['status'],
      );
    });

    test('a tile shows a price and nothing else', () {
      // It used to lead with "▶ FREE" whenever an ad slot was open, and fall
      // back to a countdown. A video buys ONE item, so neither was true of a
      // tile that sells a whole pack.
      for (final pack in lookPacks) {
        final tile = lookTileState(<String, dynamic>{}, pack.id)!;
        expect(tile.status, anyOf('gems', 'owned'));
        expect(tile.waitMs, 0);
        expect(tile.cost, greaterThan(0));
      }
    });
  });
}
