/// Custom team names, against the JS they were ported from.
///
/// A rename is a PROPAGATION — the same string lives in the pyramid, the
/// fixtures, the season opponents, the table positions, last season's badges,
/// the last result, an active cup run's opponents, results and scout blurbs, and
/// the transfer market's pending offer and grudges. Miss one and the club is
/// renamed everywhere the player can see except the screen that still calls it
/// by its old name, so the whole state is compared after each rename rather
/// than a summary of it.
///
/// The other half is the two-phase apply. Re-applying a preset after a few
/// seasons of promotion and relegation routinely asks two clubs to swap names,
/// and doing that in one pass means the second rename collides with a name the
/// first one just took.
///
/// See `tool/dump_pyramid_names_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/pyramid_names_engine.dart';
import 'package:merge_empire_fc/util/time.dart';

import '../support/js_math_random.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/pyramid_names_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

/// The state the reference was generated against.
Map<String, dynamic> _state() =>
    jsonDecode(jsonEncode(_ref['state'])) as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(String key) =>
    (_ref[key] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _section(String key) => _ref[key] as Map<String, dynamic>;

List<String> get _divIds => (_ref['divisionIds'] as List).cast<String>();

/// The JS reported a refusal as a snake-case string.
const _refusalNames = {
  NameRefusal.tooShort: 'too_short',
  NameRefusal.profanity: 'profanity',
  NameRefusal.duplicate: 'duplicate',
};

const _presetRefusalNames = {
  PresetRefusal.label: 'label',
  PresetRefusal.full: 'full',
  PresetRefusal.parse: 'parse',
};

/// Every division's names, in slot order.
Map<String, dynamic> _namesOf(Map<String, dynamic> state) {
  final pyramid =
      (state['progression'] as Map)['leaguePyramid'] as Map<String, dynamic>;
  return {
    for (final id in _divIds)
      id: [for (final t in pyramid[id] as List) (t as Map)['name']],
  };
}

List<Map<String, dynamic>> _skippedAsJson(List<SkippedAssignment> skipped) => [
  for (final s in skipped)
    {
      'divId': s.divId,
      'index': s.index,
      'name': s.name,
      'reason': _refusalNames[s.reason],
    },
];

/// A pinned clock and a pinned random stream: a preset id is
/// `pyr_<now>_<random × 1e6>` and it lands in the save.
void _pin(int at, double roll) {
  setClock(() => at);
  setPyramidNamesRandom(_FixedRandom(roll));
}

/// Returns the same double every call, matching the dump script's stub.
class _FixedRandom implements math.Random {
  _FixedRandom(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => (value * max).floor();

  @override
  bool nextBool() => value < 0.5;
}

void main() {
  setUp(() => _pin(1700000000000, 0.123456));
  tearDown(() {
    resetClock();
    resetPyramidNamesRandom();
  });

  test('the limits match the JS', () {
    final want = _section('constants');
    expect(teamNameMax, want['teamNameMax']);
    expect(teamNameMin, want['teamNameMin']);
    expect(maxPresets, want['maxPresets']);
  });

  test('parity — every name in the pyramid', () {
    expect(allTeamNames(_state()).toList()..sort(), _ref['allTeamNames']);
    expect(allTeamNames(null), isEmpty);
    expect(allTeamNames(<String, dynamic>{}), isEmpty);
  });

  test('parity — validation', () {
    for (final row in _rows('validate')) {
      final got = validateTeamName(
        _state(),
        row['raw'],
        current: row['current'] as String?,
      );
      final reason = '${row['label']}';
      expect(got.ok, row['ok'], reason: '$reason ok');
      expect(got.name, row['name'], reason: '$reason name');
      expect(
        got.reason == null ? null : _refusalNames[got.reason],
        row['reason'],
        reason: '$reason refusal',
      );
    }
  });

  test('parity — a rename reaches every name-keyed structure', () {
    for (final row in _rows('rename')) {
      final state = _state();
      final ok = renameTeam(
        state,
        row['oldName'] as String?,
        row['newName'] as String?,
      );
      expect(ok, row['ok'], reason: '${row['label']} ok');
      expect(state, row['state'], reason: '${row['label']} state');
    }
  });

  test('parity — a save missing every optional branch survives a rename', () {
    final want = _section('renameBareState');
    final state = <String, dynamic>{
      'progression': <String, dynamic>{
        'leaguePyramid': <String, dynamic>{
          'regional_league': <dynamic>[
            <String, dynamic>{'name': 'Alpha'},
          ],
        },
      },
    };
    expect(renameTeam(state, 'Alpha', 'Beta'), want['ok']);
    expect(state, want['state']);
  });

  test('parity — applying a list of names', () {
    for (final row in _rows('applyNameList')) {
      final state = _state();
      final result = applyNameList(
        state,
        row['divId'] as String,
        row['lines'] as List<Object?>?,
      );
      final reason = '${row['label']}';
      expect(result.applied, row['applied'], reason: '$reason applied');
      expect(
        _skippedAsJson(result.skipped),
        row['skipped'],
        reason: '$reason skipped',
      );
      expect(_namesOf(state), row['names'], reason: '$reason names');
      expect(state, row['state'], reason: '$reason state');
    }
  });

  test('two clubs can swap names in one pass', () {
    // The temp-name phase is the whole reason this works: renaming A to B first
    // would collide with the B that is itself about to move.
    final state = _state();
    final before = _namesOf(state)['regional_league'] as List;
    final result = applyNameList(state, 'regional_league', [
      before[1],
      before[0],
    ]);
    expect(result.applied, 2);
    expect(result.skipped, isEmpty);
    final after = _namesOf(state)['regional_league'] as List;
    expect(after[0], before[1]);
    expect(after[1], before[0]);
    // And nothing is left parked on a temp name.
    expect(allTeamNames(state).where((n) => n.startsWith('zz-tmp-')), isEmpty);
  });

  group('parity — presets', () {
    test('saving, overwriting, filling up and deleting', () {
      final want = _section('savePreset');
      final steps = (want['steps'] as List).cast<Map<String, dynamic>>();
      final state = _state();
      var i = 0;

      void check(
        ({bool ok, Map<String, dynamic>? preset, PresetRefusal? reason}) result,
      ) {
        final step = steps[i++];
        final reason = '${step['label']}';
        expect(result.ok, step['ok'], reason: '$reason ok');
        expect(
          result.reason == null ? null : _presetRefusalNames[result.reason],
          step['reason'],
          reason: '$reason refusal',
        );
        expect(result.preset, step['preset'], reason: '$reason preset');
        expect(
          listPresets(state).length,
          step['count'],
          reason: '$reason count',
        );
      }

      check(savePreset(state, 'My League'));
      _pin(1700000111000, 0.7654321);
      check(savePreset(state, 'Another'));
      renameTeam(state, 'regional_league FC 0', 'Northfield Athletic');
      _pin(1700000222000, 0.7654321);
      check(savePreset(state, 'My League'));
      check(savePreset(state, '   '));
      check(savePreset(state, null));

      var at = 1700000222000;
      for (var f = 0; f < 20 && listPresets(state).length < maxPresets; f++) {
        at += 1000;
        _pin(at, (f + 1) / 100);
        savePreset(state, 'Filler $f');
      }
      check(savePreset(state, 'One Too Many'));

      final ids = [for (final p in listPresets(state)) (p as Map)['id']];
      expect(ids, want['ids']);
      expect(deletePreset(state, 'nope'), want['deletedUnknown']);
      expect(deletePreset(state, ids[1]), want['deleted']);
      expect([
        for (final p in listPresets(state)) (p as Map)['id'],
      ], want['afterDelete']);
      expect(listPresets(state), want['presets']);
    });

    test('applying one, whatever shape it is in', () {
      final want = _section('applyPreset');
      final saved = want['saved'] as Map<String, dynamic>;
      final cases = (want['cases'] as List).cast<Map<String, dynamic>>();

      for (final row in cases) {
        final state = _state();
        final preset = jsonDecode(jsonEncode(saved)) as Map<String, dynamic>;
        switch (row['label']) {
          case 'missingDivision':
            (preset['names'] as Map).remove('regional_league');
          case 'shortList':
            (preset['names'] as Map)['regional_league'] = ['Only One'];
          case 'longList':
            (preset['names'] as Map)['regional_league'] = [
              ...(preset['names'] as Map)['regional_league'] as List,
              'Ninth',
              'Tenth',
            ];
          case 'blanksKeepTheCurrentName':
            (preset['names'] as Map)['regional_league'] = [
              'Alpha FC',
              '',
              '   ',
              'Delta FC',
            ];
          case 'namesNotAnArray':
            (preset['names'] as Map)['regional_league'] = 'nonsense';
        }
        (state['settings'] as Map)['customPyramids'] = <dynamic>[preset];

        final result = applyPreset(state, preset['id']);
        final reason = '${row['label']}';
        expect(result.applied, row['applied'], reason: '$reason applied');
        expect(
          _skippedAsJson(result.skipped),
          row['skipped'],
          reason: '$reason skipped',
        );
        expect(_namesOf(state), row['names'], reason: '$reason names');
      }

      final unknown = applyPreset(_state(), 'nope');
      expect(unknown.applied, (want['unknown'] as Map)['applied']);
      expect(unknown.skipped, isEmpty);
    });

    test('the preset the apply cases were built from', () {
      // Saved off a pyramid whose names had already been shuffled, which is
      // what re-applying after a few seasons actually looks like.
      final source = _state();
      applyNameList(source, 'regional_league', [
        'Alpha FC',
        'Bravo FC',
        'Charlie FC',
        'Delta FC',
      ]);
      expect(
        savePreset(source, 'Set').preset,
        _section('applyPreset')['saved'],
      );
    });

    test('presets live under settings, which a reset preserves', () {
      // The whole reason a saved set survives New Team.
      final state = <String, dynamic>{};
      expect(listPresets(state), isEmpty);
      expect((state['settings'] as Map)['customPyramids'], isEmpty);
      // A settings branch holding something else in that slot is replaced.
      (state['settings'] as Map)['customPyramids'] = 'nonsense';
      expect(listPresets(state), isEmpty);
    });
  });

  group('parity — the text format', () {
    test('exports, parses and imports', () {
      final want = _section('text');
      final state = _state();
      final preset = savePreset(state, 'Export Me').preset!;
      expect(exportPresetText(preset), want['exported']);

      for (final row in (want['parses'] as List).cast<Map<String, dynamic>>()) {
        expect(
          parsePresetText(row['text']),
          row['parsed'],
          reason: '${row['label']}',
        );
      }

      // A division with no names in it at all is not exported — an empty
      // section would parse back as a division of blanks.
      expect(
        exportPresetText(<String, dynamic>{
          'names': <String, dynamic>{
            'regional_league': ['Alpha', 'Bravo'],
            'elite_league': ['', ''],
          },
        }),
        want['sparseText'],
      );

      var at = 1700000000000;
      final importState = _state();
      final imports = (want['imports'] as List).cast<Map<String, dynamic>>();
      final texts = {
        'fresh': want['exported'],
        'overwritesByLabel': want['exported'],
        'unparseable': 'nothing here',
        'emptyLabel': want['exported'],
        'sanitisesNames':
            '[regional_league]\n   A Very Long Name That Runs Past The Limit   \nB',
      };
      final labels = {
        'fresh': 'Imported',
        'overwritesByLabel': 'Imported',
        'unparseable': 'Imported',
        'emptyLabel': '  ',
        'sanitisesNames': 'Sanitised',
      };
      for (final row in imports) {
        at += 5000;
        _pin(at, 0.5);
        final label = row['label'] as String;
        final result = importPresetText(
          importState,
          texts[label],
          labels[label],
        );
        expect(result.ok, row['ok'], reason: '$label ok');
        expect(
          result.reason == null ? null : _presetRefusalNames[result.reason],
          row['reason'],
          reason: '$label refusal',
        );
        expect(result.preset, row['preset'], reason: '$label preset');
        expect(
          listPresets(importState).length,
          row['count'],
          reason: '$label count',
        );
      }
    });

    test('the format is locale-proof', () {
      // Division IDS, not display names, so a set shared between two players in
      // different languages still lands in the right league.
      final state = _state();
      final text = exportPresetText(savePreset(state, 'Set').preset);
      for (final id in _divIds) {
        expect(text, contains('[$id]'));
      }
    });
  });

  test('a preset id is unique across saves in the same millisecond', () {
    // The clock alone is not enough — two presets saved in the same tick would
    // share an id, and deleting one would delete the other.
    setClock(() => 1700000000000);
    setPyramidNamesRandom(JsMathRandom(99));
    final state = _state();
    final a = savePreset(state, 'One').preset!;
    final b = savePreset(state, 'Two').preset!;
    expect(a['createdAt'], b['createdAt']);
    expect(a['id'], isNot(b['id']));
  });
}
