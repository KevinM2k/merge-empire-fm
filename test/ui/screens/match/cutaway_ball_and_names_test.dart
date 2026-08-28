/// The ball only moves when somebody plays it, and our figures carry names.
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_game.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_sequences.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart';

Future<CutawayGame> loaded(
  WidgetTester tester, {
  bool ours = true,
  List<String> names = const [],
  String? scorerName,
  CutawayOutcome outcome = CutawayOutcome.goal,
  int seed = 7,
  CutawaySequence? sequence,
}) async {
  final game = CutawayGame(
    sequence: sequence ?? cutawaySequences.first,
    attackingRight: true,
    outcome: outcome,
    seed: seed,
    ours: ours,
    names: names,
    scorerName: scorerName,
  );
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GameWidget(game: game))),
    );
    await game.loaded;
  });
  return game;
}

void main() {
  testWidgets('THE BALL ONLY MOVES WHEN SOMEBODY PLAYS IT', (tester) async {
    // A pass used to change hands the instant it landed, and the next frame
    // drew the ball at the receiver's feet wherever he had got to. Now: in
    // flight it is a kick; loose, it lies exactly still; otherwise it is at
    // the carrier's feet — a step ahead, plus the easing that follows a turn.
    for (var i = 0; i < cutawaySequences.length; i++) {
      final game = await loaded(
        tester,
        sequence: cutawaySequences[i],
        seed: 11 + i,
      );
      const step = 1 / 60;
      var last = game.ball.position.clone();
      var t = 0.0;
      var wasLoose = false;
      while (!game.finished && t < 30) {
        game.update(step);
        t += step;
        final moved = game.ball.position.distanceTo(last);
        // Once the shot has landed the ball lies where it ended up — in the
        // net, at the keeper's feet — and nobody is carrying it.
        if (game.verdict.value != null) break;
        if (game.inFlight) {
          // A kick: a long shot covers 3.3 units a frame on average, and the
          // cubic ease-out opens at three times that.
          expect(moved, lessThan(12), reason: 'sequence $i at ${t}s');
        } else if (game.isLoose && wasLoose) {
          expect(moved, 0, reason: 'sequence $i: a loose ball rolled at ${t}s');
        } else if (!game.isLoose) {
          final feet = game.attackers[game.carrier].position;
          expect(
            game.ball.position.distanceTo(feet),
            lessThan(6.5),
            reason: 'sequence $i: the ball left the carrier at ${t}s',
          );
        }
        wasLoose = game.isLoose;
        last = game.ball.position.clone();
      }
    }
  });

  testWidgets('OUR ELEVEN WEAR NAMES, theirs numbers, the keeper GK', (
    tester,
  ) async {
    final game = await loaded(
      tester,
      names: const ['John Smith', 'Solo', 'Bartholomew Oxenbould-Wexford'],
    );
    final labels = [for (final a in game.attackers) a.label];
    expect(labels, contains('Smith'));
    expect(labels, contains('Solo'), reason: 'a one-word name is the name');
    expect(labels, contains('Oxenboul…'), reason: 'cut past nine, like _short');
    // More figures than names: the rest fall back to shirt numbers.
    expect(labels.every((l) => l != null && l.isNotEmpty), isTrue);
    expect([for (final d in game.defenders) d.label], everyElement(
      matches(RegExp(r'^\d+$')),
    ));
    expect(game.keeper.label, 'GK');
  });

  testWidgets('WHEN THEY ATTACK the names are on our defenders', (
    tester,
  ) async {
    final game = await loaded(tester, ours: false, names: const ['Ada Lovelace']);
    expect([for (final d in game.defenders) d.label], contains('Lovelace'));
    expect([for (final a in game.attackers) a.label], everyElement(
      matches(RegExp(r'^\d+$')),
    ));
  });

  testWidgets('THE SCORER TAKES THE SHOT', (tester) async {
    final game = await loaded(
      tester,
      names: const ['Ada Lovelace', 'Grace Hopper'],
      scorerName: 'Grace Hopper',
    );
    // Held out of the pool, so nobody wears it before the shot.
    expect([for (final a in game.attackers) a.label], isNot(contains('Hopper')));
    var struck = false;
    game.struck.addListener(() => struck = true);
    var t = 0.0;
    while (!struck && t < 30) {
      game.update(1 / 60);
      t += 1 / 60;
    }
    expect(struck, isTrue);
    expect(game.attackers[game.carrier].label, 'Hopper');
  });

  /// **WE ARE GREEN AND THEY ARE RED, WHICHEVER SIDE HAS THE BALL.**
  ///
  /// The attackers were always the green shirts and the defenders always the
  /// red ones, so an opponent's goal replayed with THEM in green attacking our
  /// reds — the coding inverted on the one passage where it matters. Reported
  /// from an Android handset: "the user should always be the green team, the
  /// opponent should always be red, atm the scoring team is always the green
  /// regardless of home or away".
  testWidgets('THE KIT FOLLOWS THE CLUB, NOT THE DIRECTION OF PLAY', (
    tester,
  ) async {
    final ourChance = await loaded(tester, ours: true);
    expect(
      ourChance.attackers.first.sprite.image,
      same(cutawayImages.fromCache('green_1.png')),
    );
    expect(
      ourChance.defenders.first.sprite.image,
      same(cutawayImages.fromCache('red_1.png')),
    );

    final theirChance = await loaded(tester, ours: false);
    expect(
      theirChance.attackers.first.sprite.image,
      same(cutawayImages.fromCache('red_1.png')),
      reason: 'their attack was drawn in our green',
    );
    expect(
      theirChance.defenders.first.sprite.image,
      same(cutawayImages.fromCache('green_1.png')),
      reason: 'and our back line in their red',
    );
    // The labels were already right and stay so: our names, their numbers.
    expect(theirChance.defenders.first.label, isNotNull);
  });

  test('shortName is the JS _short', () {
    expect(shortName('John Smith'), 'Smith');
    expect(shortName('Solo'), 'Solo');
    expect(shortName('Bartholomew Oxenbould-Wexford'), 'Oxenboul…');
    expect(shortName('  Two  Words '), 'Words');
  });
}
