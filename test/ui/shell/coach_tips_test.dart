/// What Colin says, and which of the things he could say wins.
///
/// The catalogue carried a hundred and twenty of his lines and the port read
/// four, so almost everything here is about a pipeline that had no caller. Each
/// pool returns the FIRST thing that applies, which makes the order the whole
/// design: health before age, age before money.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/shell/coach_tips.dart';
import 'package:merge_empire_fc/ui/shell/tabs.dart';

void main() {
  setUp(() => setLocale('en'));

  /// A save with a squad of [n] cards, none of which the division will let him
  /// merge unless [pair] asks for one.
  ///
  /// The default is a tier-2 card, which in Sunday League is the CEILING — its
  /// next tier is above `maxPlayerTier`, so no pair of them is a pair the league
  /// would allow. That matters: the first cut of this helper used tier-1s, which
  /// merge, so "no pair available" was never actually being tested.
  Map<String, dynamic> saveWith({
    int n = 5,
    int injured = 0,
    bool pair = false,
    int seasonsPlayed = 0,
    num coins = 5000,
    num energy = 10,
    Map<String, dynamic>? clubAssets,
  }) {
    final save = createDefaultState();
    final cells = <Map<String, dynamic>?>[
      for (var i = 0; i < n; i++)
        <String, dynamic>{
          'instanceId': 'c$i',
          // Two tier-1s of the same definition and the same gender is a pair
          // the league permits; everything else is at the ceiling.
          'definitionId': pair && i < 2 ? 'player_t1_mid' : 'player_t2_def',
          'variant': 0,
          'seasonsPlayed': seasonsPlayed,
          if (i < injured) 'injured': true,
        },
    ];
    (save['grid'] as Map<String, dynamic>)['cells'] = cells;
    (save['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
    (save['energy'] as Map<String, dynamic>)['current'] = energy;
    if (clubAssets != null) save['clubAssets'] = clubAssets;
    return save;
  }

  group('the home tab', () {
    test('says nothing, because his orb already does', () {
      // A floating head over a screen that has him on it is the same coach
      // twice — the JS gates its Overview sub-tab the same way.
      expect(coachTipFor(saveWith(), ShellTab.home), isNull);
    });
  });

  group('the players grid', () {
    test('an injury outranks everything else it could say', () {
      final tip = coachTipFor(saveWith(n: 12, injured: 1), ShellTab.grid);
      expect(tip, isNotNull);
      expect(tip!.category, 'grid');
      // 12 cards is also "over eleven", and a merge may also be available; the
      // one thing there is to DO about an injury wins.
      expect(tip.text, isNot(contains('|')), reason: 'the pool leaked');
      final healthy = coachTipFor(saveWith(n: 12), ShellTab.grid);
      expect(tip.text, isNot(healthy!.text));
    });

    test('a full XI is worth saying on its own', () {
      final tip = coachTipFor(saveWith(n: 11), ShellTab.grid);
      expect(tip?.text, t('coach.grid.full_xi'));
    });

    test('and an empty grid gets nothing rather than a guess', () {
      expect(coachTipFor(saveWith(n: 0), ShellTab.grid), isNull);
    });

    test('a mergeable pair reads differently under a full XI', () {
      final short = coachTipFor(saveWith(n: 4, pair: true), ShellTab.grid);
      final full = coachTipFor(saveWith(n: 14, pair: true), ShellTab.grid);
      expect(short, isNotNull);
      expect(full, isNotNull);
      expect(
        short!.text,
        isNot(full!.text),
        reason: 'merging when you are short of eleven is a different call',
      );
    });
  });

  group('the squad', () {
    test('two injuries is a crisis, and it comes first', () {
      final tip = coachTipFor(
        saveWith(n: 11, injured: 2, seasonsPlayed: 14),
        ShellTab.squad,
      );
      // A final-season veteran is also true here. Health wins.
      expect(tip?.text, contains('2'));
    });

    test('a final season is a day-long tip, not a ten-minute one', () {
      final tip = coachTipFor(
        saveWith(n: 11, seasonsPlayed: 14),
        ShellTab.squad,
      );
      expect(tip, isNotNull);
      expect(
        tip!.cooldown,
        coachDayCooldown,
        reason:
            'he is still retiring in ten minutes; saying it again is nagging',
      );
    });

    test('and the age ladder runs in the order it becomes urgent', () {
      String? textAt(int seasons) => coachTipFor(
        saveWith(n: 11, seasonsPlayed: seasons),
        ShellTab.squad,
      )?.text;
      final ages = [7, 10, 13, 14].map(textAt).toList();
      expect(ages.every((t) => t != null), isTrue);
      expect(
        ages.toSet().length,
        4,
        reason: 'four different situations must not read as one',
      );
    });

    test('a traitless XI is keyed on the ADVICE, not on the sentence', () {
      // The dismissal has to survive the text changing, which is why the tips
      // that name something carry their own key.
      final tip = coachTipFor(saveWith(n: 11), ShellTab.squad);
      expect(tip, isNotNull);
      expect(tip!.dismissKey, 'squad_no_traits');
      expect(tip.cooldown, coachDayCooldown);
    });
  });

  group('the club', () {
    test('nothing built at all is the one thing worth saying', () {
      final tip = coachTipFor(
        saveWith(clubAssets: <String, dynamic>{}),
        ShellTab.club,
      );
      expect(tip?.text, t('coach.club.empty'));
    });

    test('and a shelf of tier-ones gets its own line', () {
      final tip = coachTipFor(
        saveWith(
          clubAssets: {
            for (final id in ['A', 'B', 'C', 'D'])
              id: <String, dynamic>{'owned': true, 'tier': 1},
          },
        ),
        ShellTab.club,
      );
      expect(tip?.text, t('coach.club.all_t1'));
    });

    test('a well-built club needs no advice', () {
      final tip = coachTipFor(
        saveWith(
          clubAssets: {
            for (final id in ['A', 'B', 'C'])
              id: <String, dynamic>{'owned': true, 'tier': 4},
          },
        ),
        ShellTab.club,
      );
      expect(tip, isNull);
    });
  });

  group('the shop', () {
    test('an injury on the shelf screen is still an injury', () {
      final tip = coachTipFor(saveWith(injured: 1), ShellTab.shop);
      expect(tip?.text, t('coach.shop.injured'));
    });

    test('no energy is keyed so a dismissal survives the wording', () {
      final tip = coachTipFor(saveWith(energy: 1), ShellTab.shop);
      expect(tip?.dismissKey, 'shop_low_energy');
    });

    test('broke means cannot afford the cheapest scout at this level', () {
      final tip = coachTipFor(saveWith(coins: 0), ShellTab.shop);
      expect(tip?.text, t('coach.shop.broke'));
    });

    test('and a hoard is measured against the DIVISION, not a flat number', () {
      final tip = coachTipFor(saveWith(coins: 10000000), ShellTab.shop);
      expect(tip, isNotNull);
      expect(tip!.category, 'shop');
      expect(tip.text, isNot(t('coach.shop.broke')));
    });
  });

  group('the stable pool', () {
    test('the same situation gets the same sentence, every time', () {
      // **This is the whole reason `tPoolStable` exists.** Picking at random
      // meant a different line on every rebuild, and on the Shop tab — where
      // the seed was once the coin balance — it reshuffled on every idle tick
      // and made his head flash.
      final first = coachTipFor(saveWith(n: 6), ShellTab.grid)!.text;
      for (var i = 0; i < 20; i++) {
        expect(coachTipFor(saveWith(n: 6), ShellTab.grid)!.text, first);
      }
    });

    test('and a different situation may get a different one', () {
      final six = coachTipFor(saveWith(n: 6), ShellTab.grid)!.text;
      final seeds = {
        for (var n = 2; n < 11; n++)
          coachTipFor(saveWith(n: n), ShellTab.grid)!.text,
      };
      expect(six, isIn(seeds));
      expect(
        seeds.length,
        greaterThan(1),
        reason: 'a seeded pool that always picks one line is not a pool',
      );
    });

    test('never leaks the pipes it is separated by', () {
      for (final tab in ShellTab.values) {
        for (final n in [0, 1, 5, 11, 14]) {
          final tip = coachTipFor(saveWith(n: n), tab);
          if (tip == null) continue;
          expect(tip.text, isNot(contains('|')), reason: '$tab with $n cards');
          expect(tip.text.trim(), isNotEmpty);
        }
      }
    });
  });
}
