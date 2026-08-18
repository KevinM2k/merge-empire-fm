/// The Boot Room board, against the JS it was ported from.
///
/// Every function takes its randomness as an argument, so the whole file is
/// reproducible: the reference draws from a mulberry32 and this drives an
/// identical copy. What that pins is the ORDER of the draws as much as the
/// results — `collapse` refills column by column with the top-up cells counted
/// upward, and a port that refills row-wise produces a board with exactly the
/// same tile counts and none of the same tiles.
///
/// The hand-authored boards are the other half. Cascades are easy to get right
/// and L and T shapes are not: a cell in both a row run and a column run turns
/// up in two groups, and clearing it twice is how a cross drops the wrong
/// column.
///
/// See `tool/dump_boot_room_reference.mjs`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/boot_room_engine.dart';

import '../support/js_math_random.dart';

final Map<String, dynamic> _ref =
    jsonDecode(
          File('test/fixtures/boot_room_reference.json').readAsStringSync(),
        )
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(String key) =>
    (_ref[key] as List).cast<Map<String, dynamic>>();

Map<String, dynamic> _section(String key) => _ref[key] as Map<String, dynamic>;

final int _cols = _ref['cols'] as int;
final int _rows5 = _ref['rows'] as int;

/// The hand-authored board of that name, as the reference wrote it.
List<int?> _board(String label) => [
  for (final t in (_section('boards')[label] as List)) t as int?,
];

/// The same stream the dump script drew from.
double Function() _rng(int seed) {
  final stream = JsMathRandom(seed);
  return stream.nextDouble;
}

List<Map<String, dynamic>> _groupsAsJson(List<MatchGroup> groups) => [
  for (final g in groups)
    {'type': g.type, 'horizontal': g.horizontal, 'cells': g.cells},
];

List<Map<String, dynamic>> _movesAsJson(List<TileMove> moves) => [
  for (final m in moves) {'from': m.from, 'to': m.to},
];

List<Map<String, dynamic>> _spawnedAsJson(List<TileSpawn> spawned) => [
  for (final s in spawned) {'cell': s.cell, 'height': s.height},
];

void main() {
  test('parity — the index maths', () {
    for (final row in _rows('indexing')) {
      final idx = idxOf(_cols, row['x'] as int, row['y'] as int);
      expect(idx, row['idx'], reason: '${row['x']},${row['y']}');
      expect(xOf(_cols, idx), row['backX'], reason: 'x of $idx');
      expect(yOf(_cols, idx), row['backY'], reason: 'y of $idx');
    }
  });

  test('parity — what counts as adjacent', () {
    for (final row in _rows('adjacent')) {
      expect(
        areAdjacent(_cols, row['a'] as int, row['b'] as int),
        row['adjacent'],
        reason: '${row['a']} to ${row['b']}',
      );
    }
  });

  test('parity — every run on every board', () {
    for (final entry in _section('findMatches').entries) {
      expect(
        _groupsAsJson(findMatches(_board(entry.key), _cols, _rows5)),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('parity — a shared cell clears exactly once', () {
    // A cross is the case: the centre is in both runs, and clearing it twice
    // drops the wrong column.
    for (final entry in _section('clearedCells').entries) {
      expect(
        clearedCells(findMatches(_board(entry.key), _cols, _rows5)),
        entry.value,
        reason: entry.key,
      );
    }
    final cross = findMatches(_board('crossShape'), _cols, _rows5);
    expect(cross.length, 2);
    expect(
      clearedCells(cross).length,
      lessThan(cross.fold<int>(0, (n, g) => n + g.cells.length)),
    );
  });

  test('a hole is a run-breaker, not a type', () {
    expect(findMatches(_board('withHoles'), _cols, _rows5), isEmpty);
  });

  test('parity — collapsing', () {
    for (final row in _rows('collapse')) {
      final label = row['label'] as String;
      final board = _board(
        _section('boards').containsKey(label) ? label : 'rowOfThree',
      );
      final result = collapse(
        board,
        _cols,
        _rows5,
        (row['cleared'] as List).cast<int>(),
        row['typeCount'] as int,
        _rng(row['seed'] as int),
      );
      expect(result.board, row['board'], reason: '$label board');
      expect(_movesAsJson(result.moves), row['moves'], reason: '$label moves');
      expect(
        _spawnedAsJson(result.spawned),
        row['spawned'],
        reason: '$label spawned',
      );
    }
  });

  test('parity — settling, cascade by cascade', () {
    for (final row in _rows('resolve')) {
      final label = row['label'] as String;
      final result = resolve(
        _board(label.split('_').first),
        _cols,
        _rows5,
        row['typeCount'] as int,
        _rng(row['seed'] as int),
      );
      expect(result.board, row['board'], reason: '$label board');
      expect(result.cascades, row['cascades'], reason: '$label cascades');
      expect(
        result.tilesCleared,
        row['tilesCleared'],
        reason: '$label tilesCleared',
      );
      final wantSteps = (row['steps'] as List).cast<Map<String, dynamic>>();
      expect(result.steps.length, wantSteps.length, reason: '$label steps');
      for (var i = 0; i < result.steps.length; i++) {
        final step = result.steps[i];
        final want = wantSteps[i];
        expect(step.cascade, want['cascade'], reason: '$label step $i cascade');
        expect(
          _groupsAsJson(step.groups),
          want['groups'],
          reason: '$label step $i groups',
        );
        expect(step.cleared, want['cleared'], reason: '$label step $i cleared');
        expect(
          _movesAsJson(step.moves),
          want['moves'],
          reason: '$label step $i moves',
        );
        expect(
          _spawnedAsJson(step.spawned),
          want['spawned'],
          reason: '$label step $i spawned',
        );
        expect(step.board, want['board'], reason: '$label step $i board');
      }
    }
  });

  test('parity — swapping', () {
    for (final row in _rows('trySwap')) {
      expect(
        trySwap(
          _board('checkerboard'),
          _cols,
          _rows5,
          row['a'] as int,
          row['b'] as int,
        ),
        row['board'],
        reason: '${row['label']}',
      );
    }
    expect(
      trySwap(_board('settledButDead'), _cols, _rows5, 1, 6),
      _ref['trySwapOnDeadBoard'],
    );
  });

  test('parity — finding a move', () {
    for (final entry in _section('findMove').entries) {
      final move = findMove(_board(entry.key), _cols, _rows5);
      final want = entry.value as Map<String, dynamic>?;
      if (want == null) {
        expect(move, isNull, reason: entry.key);
      } else {
        expect(move!.a, want['a'], reason: '${entry.key} a');
        expect(move.b, want['b'], reason: '${entry.key} b');
      }
    }
    for (final entry in _section('hasAnyMove').entries) {
      expect(
        hasAnyMove(_board(entry.key), _cols, _rows5),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('parity — making a board', () {
    for (final row in _rows('createBoard')) {
      final board = createBoard(
        row['cols'] as int,
        row['rows'] as int,
        row['typeCount'] as int,
        _rng(row['seed'] as int),
      );
      final reason =
          'seed ${row['seed']} ${row['cols']}x${row['rows']} '
          '${row['typeCount']} types';
      expect(board, row['board'], reason: reason);
      expect(
        findMatches(board, row['cols'] as int, row['rows'] as int).isEmpty,
        row['settled'],
        reason: '$reason settled',
      );
      expect(
        hasAnyMove(board, row['cols'] as int, row['rows'] as int),
        row['playable'],
        reason: '$reason playable',
      );
    }
  });

  test('one type cannot make a settled board, and it gives up saying so', () {
    // The caller's difficulty curve never goes there, but the give-up path is
    // what stops it spinning if it ever does.
    final row = _rows('createBoard').firstWhere((r) => r['typeCount'] == 1);
    expect(row['settled'], false);
  });

  test('parity — reshuffling', () {
    for (final row in _rows('reshuffle')) {
      final label = row['label'] as String;
      final board = switch (label) {
        'deadBoard' => _board('settledButDead'),
        'alreadyPlayable' => _board('checkerboard'),
        _ => <int?>[for (var i = 0; i < 25; i++) 3],
      };
      final next = reshuffle(
        board,
        _cols,
        _rows5,
        row['typeCount'] as int,
        _rng(row['seed'] as int),
      );
      expect(next, row['board'], reason: label);
      expect(
        findMatches(next, _cols, _rows5).isEmpty,
        row['settled'],
        reason: '$label settled',
      );
      expect(
        hasAnyMove(next, _cols, _rows5),
        row['playable'],
        reason: '$label playable',
      );
      final sameBag =
          (([...board]..sort((a, b) => (a ?? 0) - (b ?? 0))).join(',')) ==
          (([...next]..sort((a, b) => (a ?? 0) - (b ?? 0))).join(','));
      expect(sameBag, row['sameBag'], reason: '$label sameBag');
    }
  });

  test('a reshuffle keeps the same tiles unless the bag itself is dead', () {
    // One type left standing can never make a move, so the only way out is a
    // fresh board — which is the one case where the tiles change identity.
    final dead = _rows(
      'reshuffle',
    ).firstWhere((r) => r['label'] == 'deadBoard');
    final oneType = _rows(
      'reshuffle',
    ).firstWhere((r) => r['label'] == 'oneTypeOnly');
    expect(dead['sameBag'], true);
    expect(oneType['sameBag'], false);
  });

  group('without an injected draw', () {
    // The default path is the one the app runs on, and it can only be pinned to
    // the properties it has to hold.
    test('a fresh board is settled and playable', () {
      for (var i = 0; i < 20; i++) {
        final board = createBoard(6, 6, 5);
        expect(board.length, 36);
        expect(findMatches(board, 6, 6), isEmpty);
        expect(hasAnyMove(board, 6, 6), isTrue);
      }
    });

    test('a collapse fills every hole it made', () {
      final board = createBoard(6, 6, 5);
      final result = collapse(board, 6, 6, [0, 1, 2], 5);
      expect(result.board.whereType<int>().length, 36);
      expect(result.spawned.length, 3);
    });

    test('a settle leaves nothing matching', () {
      final board = [for (var i = 0; i < 36; i++) i % 3];
      final result = resolve(board, 6, 6, 5);
      expect(findMatches(result.board, 6, 6), isEmpty);
      expect(result.cascades, greaterThan(0));
    });

    test('a reshuffle of a dead board makes it playable', () {
      final next = reshuffle(_board('settledButDead'), _cols, _rows5, 4);
      expect(hasAnyMove(next, _cols, _rows5), isTrue);
    });
  });
}
