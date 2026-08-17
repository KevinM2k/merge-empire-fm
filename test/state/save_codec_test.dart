import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/state/save_codec.dart';

void main() {
  final fixture = File('test/fixtures/default_save_v7.json').readAsStringSync();

  test('decodes a real v7 save', () {
    final save = SaveCodec.decode(fixture);
    expect(save, isNotNull);
    expect(save!['version'], 7);
  });

  test('round-trips a real v7 save without losing anything', () {
    expect(SaveCodec.isLossless(fixture), isTrue);
  });

  test('preserves keys the model does not know about', () {
    final withUnknown = jsonEncode({
      ...SaveCodec.decode(fixture)!,
      'someFutureField': {'nested': true, 'n': 3},
    });

    final out = SaveCodec.decode(
      SaveCodec.encode(SaveCodec.decode(withUnknown)!),
    )!;
    expect(out['someFutureField'], {'nested': true, 'n': 3});
  });

  test('preserves nulls inside sparse grid arrays', () {
    // grid.cells is fixed-length and sparse; dropping nulls would shift every
    // card's index and silently rearrange the player's grid.
    final save = SaveCodec.decode(fixture)!;
    final cells = (save['grid'] as Map<String, dynamic>)['cells'] as List;
    final out = SaveCodec.decode(SaveCodec.encode(save))!;
    final outCells = (out['grid'] as Map<String, dynamic>)['cells'] as List;

    expect(outCells.length, cells.length);
    expect(outCells, cells);
  });

  test('preserves card positions in a sparsely populated grid', () {
    // The default save's grid is empty, so plant cards at non-contiguous
    // indices — this is the case that would actually expose null-stripping.
    final save = SaveCodec.decode(fixture)!;
    final grid = save['grid'] as Map<String, dynamic>;
    final cells = List<dynamic>.from(grid['cells'] as List);
    cells[0] = {'defId': 'bronze_rookie', 'tier': 1};
    cells[7] = {'defId': 'silver_starter', 'tier': 2};
    cells[38] = {'defId': 'gold_pro', 'tier': 3};
    grid['cells'] = cells;

    final out = SaveCodec.decode(SaveCodec.encode(save))!;
    final outCells = (out['grid'] as Map<String, dynamic>)['cells'] as List;

    expect(outCells.length, 39);
    expect(outCells[0], {'defId': 'bronze_rookie', 'tier': 1});
    expect(outCells[7], {'defId': 'silver_starter', 'tier': 2});
    expect(outCells[38], {'defId': 'gold_pro', 'tier': 3});
    expect(outCells[1], isNull);
    expect(outCells[37], isNull);
    expect(outCells.where((c) => c == null).length, 36);
  });

  test('preserves numeric types and does not coerce ints to doubles', () {
    // Coin balances and timestamps are ints in JS. Re-encoding them as 1.0
    // would change the save's bytes and break equality against the cloud copy.
    final save = SaveCodec.decode(fixture)!;
    final resources = save['resources'] as Map<String, dynamic>;
    expect(resources['fanCoins'], isA<int>());

    final out = SaveCodec.decode(SaveCodec.encode(save))!;
    expect((out['resources'] as Map<String, dynamic>)['fanCoins'], isA<int>());
    expect(out['createdAt'], isA<int>());
  });

  test('returns null on malformed JSON', () {
    expect(SaveCodec.decode('{"version":'), isNull);
  });

  test('returns null when the root is not an object', () {
    expect(SaveCodec.decode('[1,2,3]'), isNull);
  });

  test('returns null on an empty string', () {
    expect(SaveCodec.decode(''), isNull);
  });
}
