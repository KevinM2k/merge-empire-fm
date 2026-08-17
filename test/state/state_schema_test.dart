import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/i18n/detect.dart';
import 'package:merge_empire_fc/state/save_codec.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/time.dart';

/// Paths whose values legitimately differ from the JS fixture on every run:
/// wall-clock stamps, the random per-definition ratios, and the device locale.
const _volatile = <String>{
  'createdAt',
  'lastSeen',
  'energy.lastRegenAt',
  'definitionRatios',
  'settings.locale',
};

/// Recursively collects `path -> value` for every leaf, and `path` for every
/// container, so two states can be compared on shape and on content separately.
void _walk(
  Object? node,
  String path,
  Map<String, Object?> leaves,
  List<String> keyOrder,
) {
  if (node is Map<String, dynamic>) {
    for (final key in node.keys) {
      final child = path.isEmpty ? key : '$path.$key';
      keyOrder.add(child);
      if (_volatile.contains(child)) continue;
      _walk(node[key], child, leaves, keyOrder);
    }
  } else if (node is List) {
    leaves['$path.length'] = node.length;
    for (var i = 0; i < node.length; i++) {
      _walk(node[i], '$path[$i]', leaves, keyOrder);
    }
  } else {
    leaves[path] = node;
  }
}

void main() {
  final fixture =
      SaveCodec.decode(File('test/fixtures/default_save_v7.json').readAsStringSync())!;

  setUp(() {
    resetClock();
    resetDeviceLocales();
  });

  group('shape parity with the JS default save', () {
    test('has exactly the same keys, in the same order, at every depth', () {
      // Key order matters: jsonEncode emits insertion order, so a reordered
      // map serialises differently for identical data — which would make
      // byte-comparison against the JS save useless.
      final dartOrder = <String>[];
      final jsOrder = <String>[];
      _walk(createDefaultState(), '', {}, dartOrder);
      _walk(fixture, '', {}, jsOrder);

      expect(dartOrder, jsOrder);
    });

    test('every non-volatile leaf value matches the JS fixture', () {
      final dartLeaves = <String, Object?>{};
      final jsLeaves = <String, Object?>{};
      _walk(createDefaultState(), '', dartLeaves, []);
      _walk(fixture, '', jsLeaves, []);

      expect(dartLeaves.keys.toSet(), jsLeaves.keys.toSet());
      for (final key in jsLeaves.keys) {
        expect(dartLeaves[key], jsLeaves[key], reason: key);
      }
    });

    test('has 32 top-level keys', () {
      expect(createDefaultState().keys.length, 32);
      expect(createDefaultState().keys.toList(), fixture.keys.toList());
    });
  });

  group('round-tripping', () {
    test('a fresh state is losslessly encodable', () {
      expect(SaveCodec.isLossless(SaveCodec.encode(createDefaultState())), isTrue);
    });

    test('re-decoding preserves every value', () {
      final state = createDefaultState();
      final round = SaveCodec.decode(SaveCodec.encode(state))!;
      expect(jsonEncode(round), jsonEncode(state));
    });
  });

  group('core values', () {
    test('stamps the current save version', () {
      expect(createDefaultState()['version'], saveVersion);
      expect(createDefaultState()['version'], 7);
    });

    test('starts with the configured coins and a full energy tank', () {
      final state = createDefaultState();
      expect((state['resources'] as Map)['fanCoins'], startingCoins);
      expect((state['energy'] as Map)['current'], Energy.max);
    });

    test('starts with no gems — they are never converted from coins', () {
      expect((createDefaultState()['resources'] as Map)['gems'], 0);
    });

    test('grid is a fixed-length sparse array of nulls', () {
      final cells = (createDefaultState()['grid'] as Map)['cells'] as List;
      expect(cells.length, Grid.totalCells);
      expect(cells.every((c) => c == null), isTrue);
    });

    test('the grid array is growable, so migration can pad it', () {
      final cells = (createDefaultState()['grid'] as Map)['cells'] as List;
      expect(() => cells.add(null), returnsNormally);
    });

    test('starts in the bottom division with only it unlocked', () {
      final prog = createDefaultState()['progression'] as Map;
      expect(prog['currentDivision'], 'sunday_league');
      expect(prog['divisionsUnlocked'], ['sunday_league']);
      expect(prog['seasonCount'], 1);
    });

    test('starts in Casual mode', () {
      expect((createDefaultState()['settings'] as Map)['hardMode'], false);
    });

    test('the tutorial has not been done', () {
      final tut = createDefaultState()['tutorial'] as Map;
      expect(tut['done'], false);
      expect(tut['step'], 0);
    });
  });

  group('timestamps', () {
    test('createdAt, lastSeen and lastRegenAt share one instant', () {
      // Three separate now() calls in the JS; taking one reading keeps a fresh
      // save internally consistent and makes the value testable.
      setClock(() => 1700000000000);
      final state = createDefaultState();

      expect(state['createdAt'], 1700000000000);
      expect(state['lastSeen'], 1700000000000);
      expect((state['energy'] as Map)['lastRegenAt'], 1700000000000);
    });

    test('reads the injected clock', () {
      setClock(() => 42);
      expect(createDefaultState()['createdAt'], 42);
    });
  });

  group('definitionRatios', () {
    test('carries one ratio per player definition', () {
      final ratios = createDefaultState()['definitionRatios'] as Map;
      expect(ratios.keys.toSet(), players.map((p) => p.id).toSet());
    });

    test('matches the fixture key-for-key', () {
      final ratios = createDefaultState()['definitionRatios'] as Map;
      final fixtureRatios = fixture['definitionRatios'] as Map;
      expect(ratios.keys.toList(), fixtureRatios.keys.toList());
    });

    test('is rolled fresh each time', () {
      // Two fresh saves should not share a ratio table; a fixed table would
      // mean every player's cards had identical splits.
      final a = createDefaultState()['definitionRatios'] as Map;
      final b = createDefaultState()['definitionRatios'] as Map;
      expect(a.entries.any((e) => b[e.key] != e.value), isTrue);
    });
  });

  group('locale', () {
    test('defaults to English with no device locales', () {
      expect((createDefaultState()['settings'] as Map)['locale'], 'en');
    });

    test('narrows the device language to a shipped catalogue', () {
      setDeviceLocales(['fr-CA', 'en-GB']);
      expect((createDefaultState()['settings'] as Map)['locale'], 'fr');
    });

    test('falls back to English for an unsupported language', () {
      setDeviceLocales(['sv-SE']);
      expect((createDefaultState()['settings'] as Map)['locale'], 'en');
    });
  });

  group('freshness', () {
    test('each call returns an independent state', () {
      final a = createDefaultState();
      final b = createDefaultState();

      (a['resources'] as Map)['fanCoins'] = 999999;
      ((a['grid'] as Map)['cells'] as List)[0] = {'x': 1};

      expect((b['resources'] as Map)['fanCoins'], startingCoins);
      expect(((b['grid'] as Map)['cells'] as List)[0], isNull);
    });

    test('nested collections are not shared between states', () {
      final a = createDefaultState();
      final b = createDefaultState();
      ((a['progression'] as Map)['divisionsUnlocked'] as List).add('amateur_cup');
      expect((b['progression'] as Map)['divisionsUnlocked'], ['sunday_league']);
    });
  });

  group('lifetime gem ledger', () {
    test('starts empty so New Team cannot farm gems', () {
      final grants = createDefaultState()['gemGrants'] as Map;
      expect(grants['divisionFirsts'], isEmpty);
      expect(grants['cupFirsts'], isEmpty);
      expect(grants['questDivisionFirsts'], isEmpty);
      expect(grants['tutorialGranted'], false);
      expect(grants['firstPrestigeDone'], false);
    });

    test('a new save needs no tutorial back-fill', () {
      // The flag only means something to saves predating the gem system.
      expect((createDefaultState()['gemGrants'] as Map)['tutorialBackfilled'], true);
    });
  });
}
