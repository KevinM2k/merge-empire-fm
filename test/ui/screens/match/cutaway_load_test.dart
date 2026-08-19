/// The cutaway actually loads its sprites.
///
/// The path prefix is a string, and a wrong one fails at LOAD with an
/// exception the game swallows into a blank pitch — the analyzer cannot see it
/// and the geometry tests do not touch it.
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_sequences.dart';

void main() {
  testWidgets('every sprite the game asks for resolves', (tester) async {
    final game = CutawayGame(
      sequence: cutawaySequences.first,
      attackingRight: true,
      outcome: CutawayOutcome.goal,
      seed: 1,
    );

    // `runAsync`, not `pump`: decoding a PNG is real async I/O and the fake
    // clock a widget test runs under never lets it finish. Without this the
    // game simply never loads and the test proves nothing.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GameWidget(game: game)),
        ),
      );
      await game.loaded;
    });

    expect(game.isLoaded, isTrue);
    expect(game.attackers, isNotEmpty);
    expect(game.defenders, hasLength(5));
  });

  testWidgets('a passage advances and reaches its outcome', (tester) async {
    // The script runner is a state machine over beats. If a beat never
    // completes the clip stalls silently on a full-looking pitch, which is the
    // one failure the geometry tests cannot see.
    late CutawayOutcome ended;
    var done = false;
    final game = CutawayGame(
      sequence: cutawaySequences.firstWhere((s) => s.id == 'through_center'),
      attackingRight: true,
      outcome: CutawayOutcome.goal,
      seed: 7,
      onDone: (outcome) {
        ended = outcome;
        done = true;
      },
    );

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GameWidget(game: game)),
        ),
      );
      await game.loaded;
    });

    final startedAt = game.beatIndex;
    // Twelve seconds of match time, stepped by hand — long enough for the
    // longest passage in the table.
    for (var i = 0; i < 720 && !done; i++) {
      game.update(1 / 60);
    }

    expect(done, isTrue, reason: 'the passage never resolved');
    expect(ended, CutawayOutcome.goal);
    expect(game.beatIndex, greaterThan(startedAt));
    expect(game.finished, isTrue);
  });

  testWidgets('every passage in the table resolves', (tester) async {
    // One stalling beat type is a chance that hangs on screen until the match
    // ends. Cheap to check for all 29 and impossible to notice by playing.
    final stalled = <String>[];

    for (final sequence in cutawaySequences) {
      var done = false;
      final game = CutawayGame(
        sequence: sequence,
        attackingRight: sequence.id.hashCode.isEven,
        outcome: CutawayOutcome.saved,
        seed: sequence.id.hashCode,
        onDone: (_) => done = true,
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: GameWidget(game: game)),
          ),
        );
        await game.loaded;
      });
      for (var i = 0; i < 1200 && !done; i++) {
        game.update(1 / 60);
      }
      if (!done) stalled.add(sequence.id);
    }

    expect(stalled, isEmpty);
  });
}
