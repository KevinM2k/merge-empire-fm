import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';

final Map<String, dynamic> _ref = jsonDecode(
  File('test/fixtures/manager_looks_reference.json').readAsStringSync(),
) as Map<String, dynamic>;

/// The wardrobe, by the axis name the requirement keys use.
final Map<String, List<String>> _axes = {
  'build': buildIds,
  'outfit': outfitIds,
  'hair': hairStyleIds,
  'beard': facialHairIds,
  'hat': hatIds,
  'face': faceIds,
  'ball': ballIds,
  'neck': neckIds,
  'color': hairColorIds,
  'mood': moodMouthIds,
};

/// A fully dressed look, wearing the most gated thing on every axis.
const Map<String, dynamic> _dressed = {
  'build': 'broad',
  'outfit': 'suit',
  'style': 'slick',
  'hair': '#e0559b',
  'skin': '#8d5a2b',
  'skinShade': '#6e421c',
  'beard': 'full',
  'hat': 'diamond',
  'face': 'monocle',
  'ball': 'classic',
  'neck': 'none',
};

final Map<String, Map<String, dynamic>> _states = {
  'bare': <String, dynamic>{},
  'fanzone3': {
    'clubAssets': {
      'FANZONE': {'owned': true, 'tier': 3},
    },
  },
  'fanzone8': {
    'clubAssets': {
      'FANZONE': {'owned': true, 'tier': 8},
    },
  },
  'vault': {
    'shop': {
      'purchasedIds': ['style_vault'],
    },
  },
  'onePack': {
    'club': {
      'lookPacks': ['pack_legend'],
    },
  },
  'oneItem': {
    'club': {
      'lookItems': ['hat:viking'],
    },
  },
  'wonCup': {
    'club': {
      'cupLooksWon': ['world_club_cup'],
    },
  },
  'trophyOnly': {
    'progression': {
      'leagueTrophies': [
        {'cup': true, 'division': 'continental_cup'},
      ],
    },
  },
};

void main() {
  group('parity — the wardrobe', () {
    test('every axis holds exactly the ids the JS does, in order', () {
      // The port keeps only the unlock half of the avatar module; the geometry
      // stays with the renderer. That split is only sound because the
      // normaliser's membership checks are these lists.
      final want = _ref['ids'] as Map<String, dynamic>;
      for (final entry in _axes.entries) {
        expect(entry.value, want[entry.key], reason: entry.key);
      }
    });

    test('hair colours and skin tones match', () {
      final wantColors = _ref['hairColors'] as List;
      expect(hairColors.length, wantColors.length);
      for (var i = 0; i < hairColors.length; i++) {
        final w = wantColors[i] as Map<String, dynamic>;
        expect(hairColors[i].id, w['id']);
        expect(hairColors[i].color, w['color']);
      }
      final wantTones = _ref['skinTones'] as List;
      expect(skinTones.length, wantTones.length);
      for (var i = 0; i < skinTones.length; i++) {
        expect([skinTones[i].$1, skinTones[i].$2], wantTones[i]);
      }
    });

    test('the unlock tables match', () {
      expect(
        {for (final e in fanzoneLookUnlocks.entries) '${e.key}': e.value},
        _ref['fanzone'],
      );
      expect(cupLookUnlocks, _ref['cup']);
      expect(styleVaultId, _ref['styleVaultId']);
    });

    test('the packs match, item for item', () {
      final want = (_ref['packs'] as List).cast<Map<String, dynamic>>();
      expect(lookPacks.length, want.length);
      for (var i = 0; i < lookPacks.length; i++) {
        expect(lookPacks[i].id, want[i]['id']);
        expect(lookPacks[i].tint, want[i]['tint']);
        expect(lookPacks[i].icon, want[i]['icon']);
        expect(lookPacks[i].items, want[i]['items']);
      }
    });
  });

  group('parity — how each piece is obtained', () {
    test('every id on every axis resolves the same way', () {
      for (final entry in (_ref['requirements'] as Map<String, dynamic>).entries) {
        final parts = entry.key.split(':');
        final got = lookRequirement(parts[0], parts[1]);
        final want = entry.value as Map<String, dynamic>?;
        if (want == null) {
          expect(got, isNull, reason: entry.key);
          continue;
        }
        expect(got, isNotNull, reason: entry.key);
        expect(got!.fanTier, want['fanTier'], reason: entry.key);
        expect(got.cupId, want['cupId'], reason: entry.key);
        expect(got.packId, want['packId'], reason: entry.key);
      }
    });

    test('and every id is unlocked or locked identically, in every save', () {
      for (final stateEntry in _states.entries) {
        final want =
            (_ref['unlocked'] as Map<String, dynamic>)[stateEntry.key]
                as Map<String, dynamic>;
        for (final axis in _axes.entries) {
          for (final id in axis.value) {
            final key = '${axis.key}:$id';
            expect(
              isLookUnlocked(stateEntry.value, axis.key, id),
              want[key],
              reason: '${stateEntry.key} $key',
            );
          }
        }
        expect(unlockedPackIds(stateEntry.value), want['packIds'],
            reason: stateEntry.key);
        expect(persistentLookPacks(stateEntry.value), want['persistentPacks'],
            reason: stateEntry.key);
        expect(persistentLookItems(stateEntry.value), want['persistentItems'],
            reason: stateEntry.key);
      }
    });
  });

  group('parity — normalising a stored look', () {
    test('coerces every shape the same way', () {
      final cases = <String, Object?>{
        'empty': <String, dynamic>{},
        'legacyHat': {'acc': 'crown'},
        'legacyFace': {'acc': 'shades'},
        'legacyUnknownAcc': {'acc': 'nonsense'},
        'legacyAccWithNewField': {'acc': 'crown', 'hat': 'viking'},
        'garbage': {
          'build': 7,
          'outfit': <dynamic>[],
          'style': <String, dynamic>{},
          'beard': 'nope',
          'hat': 'nope',
          'face': 'nope',
        },
        'neckIsAlwaysBare': {'neck': 'scarf'},
        'ballIsAlwaysClassic': {'ball': 'gold'},
        // Everything valid, so nothing should be coerced.
        'full': {
          'build': 'broad',
          'outfit': 'suit',
          'style': 'braids',
          'hair': '#e0559b',
          'skin': '#8d5a2b',
          'skinShade': '#6e421c',
          'beard': 'full',
          'hat': 'viking',
          'face': 'monocle',
          'ball': 'classic',
          'neck': 'none',
        },
      };
      final want = _ref['normalized'] as Map<String, dynamic>;
      // `nullish` is the one case with no deterministic answer — a non-object
      // falls straight through to a random look, so it is asserted below as a
      // shape rather than compared against one roll of the JS's dice.
      expect(cases.keys.toSet(), want.keys.toSet()..remove('nullish'));

      for (final entry in cases.entries) {
        final n = normalizeAvatar(entry.value);
        final w = want[entry.key] as Map<String, dynamic>;
        // The random half of the fallback can't be compared; only the fields
        // the normaliser is deterministic about are checked.
        for (final field in ['build', 'outfit', 'beard', 'hat', 'face', 'ball', 'neck']) {
          expect(n[field], w[field], reason: '${entry.key} $field');
        }
      }
    });

    test('anything that is not an object falls through to a random look', () {
      for (final input in [null, 'nonsense', 42, <dynamic>[]]) {
        final n = normalizeAvatar(input);
        expect(buildIds, contains(n['build']), reason: '$input');
        expect(outfitIds, contains(n['outfit']), reason: '$input');
        expect(hairStyleIds, contains(n['style']), reason: '$input');
      }
    });
  });

  group('parity — sanitising against what the player owns', () {
    test('strips exactly what the JS strips, in every save', () {
      final want = _ref['sanitized'] as Map<String, dynamic>;
      for (final entry in _states.entries) {
        final s = sanitizeAvatar(entry.value, _dressed);
        final w = want[entry.key] as Map<String, dynamic>;
        for (final field in [
          'build',
          'outfit',
          'style',
          'hair',
          'beard',
          'hat',
          'face',
          'ball',
        ]) {
          expect(s[field], w[field], reason: '${entry.key} $field');
        }
      }
    });
  });

  group('the shape of the catalogue', () {
    test('pack ids are unique', () {
      final ids = [for (final p in lookPacks) p.id];
      expect(ids.toSet().length, ids.length);
    });

    test('no item belongs to two packs', () {
      final all = [for (final p in lookPacks) ...p.items];
      expect(all.toSet().length, all.length);
    });

    test('and no packed item is also Fan Zone or cup gated', () {
      // The requirement map is last-write-wins, so an overlap would silently
      // reclassify an earned cosmetic as a buyable one.
      final packed = {for (final p in lookPacks) ...p.items};
      final earned = {
        for (final keys in fanzoneLookUnlocks.values) ...keys,
        for (final keys in cupLookUnlocks.values) ...keys,
      };
      expect(packed.intersection(earned), isEmpty);
    });

    test('every gated key names a real id on a real axis', () {
      for (final key in [
        for (final keys in fanzoneLookUnlocks.values) ...keys,
        for (final keys in cupLookUnlocks.values) ...keys,
        for (final p in lookPacks) ...p.items,
      ]) {
        final parts = key.split(':');
        expect(parts.length, 2, reason: key);
        // Emotes are a rendering axis and have no id list here.
        if (parts[0] == 'emote') continue;
        expect(_axes.keys, contains(parts[0]), reason: key);
        expect(_axes[parts[0]], contains(parts[1]), reason: key);
      }
    });

    test('every cup in the unlock table is a real cup', () {
      expect(cupLookUnlocks.keys.toSet(), {
        'regional_cup',
        'national_cup',
        'continental_cup',
        'world_club_cup',
      });
    });

    test('the Fan Zone unlocks stop at its top tier', () {
      expect(fanzoneLookUnlocks.keys.reduce((a, b) => a > b ? a : b), 8);
      expect(fanzoneLookUnlocks.keys.reduce((a, b) => a < b ? a : b), 1);
    });
  });

  group('the rules the wardrobe has to keep', () {
    test('money buys flair, never progress or silverware', () {
      // The Vault short-circuits PACK ownership only.
      const vault = {
        'shop': {
          'purchasedIds': ['style_vault'],
        },
      };
      expect(isLookUnlocked(vault, 'hat', 'diamond'), isFalse);
      expect(isLookUnlocked(vault, 'hair', 'slick'), isFalse);
      expect(isLookUnlocked(vault, 'hat', 'tophat'), isTrue);
    });

    test('a cup exclusive cannot be granted by a video', () {
      // The diamond crown is worthless the moment a video can buy it.
      final state = <String, dynamic>{};
      expect(grantLookItem(state, 'hat:diamond'), isFalse);
      expect(grantLookItem(state, 'hair:slick'), isFalse);
      expect(grantLookItem(state, 'hat:tophat'), isTrue);
    });

    test('granting the same item twice does nothing', () {
      final state = <String, dynamic>{};
      expect(grantLookItem(state, 'hat:tophat'), isTrue);
      expect(grantLookItem(state, 'hat:tophat'), isFalse);
      expect(state['club']['lookItems'], ['hat:tophat']);
    });

    test('granting an unknown item or pack is refused', () {
      final state = <String, dynamic>{};
      expect(grantLookItem(state, 'hat:nonsense'), isFalse);
      expect(grantLookItem(state, 'malformed'), isFalse);
      expect(grantLookItem(state, null), isFalse);
      expect(grantLookPack(state, 'pack_nonsense'), isFalse);
      expect(grantLookPack(null, 'pack_legend'), isFalse);
    });

    test('a pack completed item by item counts as unlocked', () {
      // Or the shop's "8 / 10" line would never move for a free player.
      final state = <String, dynamic>{};
      final pack = getLookPack('pack_swagger')!;
      for (final item in pack.items) {
        grantLookItem(state, item);
      }
      expect(isPackComplete(state, 'pack_swagger'), isTrue);
      expect(unlockedPackIds(state), contains('pack_swagger'));
      // But it is NOT owned outright, so it doesn't survive as a pack.
      expect(persistentLookPacks(state), isEmpty);
      expect(persistentLookItems(state), pack.items);
    });

    test('a pack bought outright stays bought when its contents change', () {
      final state = <String, dynamic>{};
      grantLookPack(state, 'pack_legend');
      for (final item in getLookPack('pack_legend')!.items) {
        expect(isLookUnlocked(state, item.split(':')[0], item.split(':')[1]),
            isTrue, reason: item);
      }
      expect(packUnlockedCount(state, 'pack_legend'),
          getLookPack('pack_legend')!.items.length);
    });

    test('a pack that has left the catalogue is dropped on a reset', () {
      final state = {
        'club': {
          'lookPacks': ['pack_legend', 'pack_retired'],
          'lookItems': ['hat:tophat', 'hat:retired'],
        },
      };
      expect(persistentLookPacks(state), ['pack_legend']);
      expect(persistentLookItems(state), ['hat:tophat']);
    });

    test('a Fan Zone cosmetic is not persistent — it is re-earned', () {
      // It belongs to the CLUB, and prestige builds a new one.
      final state = {
        'club': {
          'lookItems': ['hair:slick'],
        },
      };
      expect(persistentLookItems(state), isEmpty);
    });

    test('the trophy cabinet grants retroactive cup credit', () {
      // Session-only, but it covers a save that won cups before the exclusives
      // existed.
      final state = {
        'progression': {
          'leagueTrophies': [
            {'cup': true, 'division': 'regional_cup'},
            {'cup': false, 'division': 'elite_league'},
          ],
        },
      };
      expect(wonCupIds(state), {'regional_cup'});
      expect(isLookUnlocked(state, 'hair', 'fauxhawk'), isTrue);
    });

    test('and the permanent record outlives it', () {
      final state = {
        'club': {
          'cupLooksWon': ['world_club_cup'],
        },
        'progression': {'leagueTrophies': <dynamic>[]},
      };
      expect(isLookUnlocked(state, 'hat', 'diamond'), isTrue);
    });
  });

  group('sanitising', () {
    test('every fallback is free from the start', () {
      // A sanitised look has to be a valid figure no matter what the player has
      // lost.
      final bare = sanitizeAvatar(<String, dynamic>{}, _dressed);
      for (final entry in {
        'build': 'build',
        'outfit': 'outfit',
        'hair': 'style',
        'beard': 'beard',
        'hat': 'hat',
        'face': 'face',
        'ball': 'ball',
      }.entries) {
        expect(
          isLookUnlocked(<String, dynamic>{}, entry.key, bare[entry.value] as String?),
          isTrue,
          reason: entry.value,
        );
      }
      expect(lookRequirement('color', freeHairColorId), isNull);
    });

    test('keeps what the player still owns', () {
      final state = {
        'clubAssets': {
          'FANZONE': {'owned': true, 'tier': 8},
        },
      };
      expect(sanitizeAvatar(state, _dressed)['style'], 'slick');
    });

    test('a bare save gets a valid look out of nothing', () {
      final look = sanitizeAvatar(null, null);
      expect(buildIds, contains(look['build']));
      expect(outfitIds, contains(look['outfit']));
      expect(hairStyleIds, contains(look['style']));
      expect(hairColorId(look['hair'] as String?), isNotNull);
    });
  });

  group('randomAvatar', () {
    test('always produces a valid look', () {
      for (var i = 0; i < 200; i++) {
        final a = randomAvatar();
        expect(buildIds, contains(a['build']));
        expect(outfitIds, contains(a['outfit']));
        expect(hairStyleIds, contains(a['style']));
        expect(facialHairIds, contains(a['beard']));
        expect(hatIds, contains(a['hat']));
        expect(faceIds, contains(a['face']));
        expect(a['ball'], 'classic');
        expect(a['neck'], 'none');
        expect(hairColorId(a['hair'] as String?), isNotNull);
      }
    });

    test('rolls only from what a save has unlocked', () {
      final bare = <String, dynamic>{};
      for (var i = 0; i < 200; i++) {
        final a = randomAvatar(bare);
        for (final entry in {'hair': 'style', 'beard': 'beard', 'hat': 'hat', 'face': 'face'}.entries) {
          expect(
            isLookUnlocked(bare, entry.key, a[entry.value] as String?),
            isTrue,
            reason: '${entry.value} ${a[entry.value]}',
          );
        }
      }
    });

    test('the head slots stay quiet — a reroll is a manager, not a novelty', () {
      var hatted = 0;
      var faced = 0;
      for (var i = 0; i < 600; i++) {
        final a = randomAvatar();
        if (a['hat'] != 'none') hatted++;
        if (a['face'] != 'none') faced++;
      }
      expect(hatted / 600, lessThan(0.4));
      expect(faced / 600, lessThan(0.35));
    });
  });
}
