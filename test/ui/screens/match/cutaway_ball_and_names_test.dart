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

  testWidgets('AND EVERY KICK COMES OFF A BOOT', (tester) async {
    // The rule the test above cannot see. It bounds how FAR the ball moves in
    // flight, which says a kick is a kick — but a flight starts wherever the
    // ball is lying, so the question a ball moving on its own actually asks is
    // whether anybody was AT it when it left.
    for (var i = 0; i < cutawaySequences.length; i++) {
      for (final outcome in [CutawayOutcome.goal, CutawayOutcome.saved]) {
        final game = await loaded(
          tester,
          sequence: cutawaySequences[i],
          outcome: outcome,
          seed: 23 + i,
        );
        const step = 1 / 60;
        var t = 0.0;
        var wasFlight = false;
        while (!game.finished && t < 30) {
          final from = game.ball.position.clone();
          final grounded = !game.inFlight;
          game.update(step);
          t += step;
          if (game.inFlight && !wasFlight && grounded) {
            var nearest = double.infinity;
            for (final a in game.attackers) {
              final d = a.position.distanceTo(from);
              if (d < nearest) nearest = d;
            }
            // A figure is 5.2 units wide, so this is a boot on the ball rather
            // than a man in the same half as it. Measured across every
            // sequence, every outcome and four seeds, the worst is 2.9.
            expect(
              nearest,
              lessThan(4),
              reason: '${cutawaySequences[i].id} $outcome at ${t}s',
            );
          }
          wasFlight = game.inFlight;
        }
      }
    }
  });

  testWidgets('AND THE MAN WHO TAKES A FREE KICK IS STANDING OVER IT', (
    tester,
  ) async {
    // **The last place the ball moved with nobody at it.** A foul spots the
    // ball and holds it for a beat so the wall is seen to form — but the taker
    // was never told to stop, so he walked on to the target his DRIBBLE beat
    // had given him. Measured at 5.2 units before the fix, which is a figure's
    // own width: the ball sat on the grass, the man who was about to kick it
    // strolled past it, and then it flew.
    //
    // A target of its own would not have done it, and that is the part worth
    // keeping: a `Mover` that has arrived damps its velocity at 6 per second
    // rather than dropping it, so a man told to stand where he already is still
    // coasts several units past it. He is FROZEN, which is what the wall beside
    // him does and what being scythed down looks like.
    var takersSeen = 0;
    for (var i = 0; i < cutawaySequences.length; i++) {
      final game = await loaded(
        tester,
        sequence: cutawaySequences[i],
        seed: 41 + i,
      );
      const step = 1 / 60;
      var t = 0.0;
      var pending = false;
      var seen = false;
      while (!game.finished && t < 30) {
        final was = game.freeKickPending;
        if (was) {
          pending = true;
          expect(
            game.attackers[game.carrier].position.distanceTo(
              game.ball.position,
            ),
            lessThan(1),
            reason: '${cutawaySequences[i].id}: the taker left it at ${t}s',
          );
        }
        game.update(step);
        t += step;
        if (was && !game.freeKickPending && !seen) {
          seen = true;
          // And he is on his feet again the frame he has struck it: a scorer
          // who cannot run is a celebration that does not happen.
          expect(
            game.attackers[game.carrier].frozen,
            isFalse,
            reason: '${cutawaySequences[i].id}: the taker is still planted',
          );
        }
      }
      if (pending) takersSeen++;
    }
    // Not vacuous: some of the scripts really do end in a foul.
    expect(takersSeen, greaterThan(0));
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

  testWidgets('THE SCORER TAKES THE SHOT, wearing his name all along', (
    tester,
  ) async {
    // **AND NOBODY IS RENAMED MID-PASSAGE, which is the bug this caught.** The
    // JS forces the scorer's name onto the shooter's dot at the moment of the
    // shot and the port copied it — the carrier took the scorer's name and
    // handed his own to whoever had been wearing it, so TWO labels on the pitch
    // changed on the frame the ball was struck. Reported from a handset, live
    // and in the replay, which are the same game.
    final game = await loaded(
      tester,
      names: const ['Ada Lovelace', 'Grace Hopper'],
      scorerName: 'Grace Hopper',
    );
    final before = [for (final a in game.attackers) a.label];
    expect(before, contains('Hopper'), reason: 'he is named at kick-off');
    expect(
      before.where((l) => l == 'Hopper'),
      hasLength(1),
      reason: 'and only one figure wears it',
    );

    var struck = false;
    game.struck.addListener(() => struck = true);
    var t = 0.0;
    while (t < 30) {
      game.update(1 / 60);
      t += 1 / 60;
      expect(
        [for (final a in game.attackers) a.label],
        before,
        reason: 'a label changed ${t.toStringAsFixed(2)}s in',
      );
      if (struck && t > 2) break;
    }
    expect(struck, isTrue);
    expect(game.attackers[game.carrier].label, 'Hopper');
  });

  testWidgets('and the cast knows who will shoot before a ball is kicked', (
    tester,
  ) async {
    // The carrier walks the same chain every run — he starts on 0 and becomes
    // each pass's receiver in turn — so the finisher comes off the script.
    // Asserted against the game actually playing it out, on every sequence,
    // because a cast that disagrees with the run puts the scorer's name on the
    // wrong shirt for ninety seconds instead of for one frame.
    for (final sequence in cutawaySequences) {
      final game = await loaded(tester, sequence: sequence);
      var struck = false;
      game.struck.addListener(() => struck = true);
      var t = 0.0;
      while (!struck && t < 30) {
        game.update(1 / 60);
        t += 1 / 60;
      }
      expect(struck, isTrue, reason: sequence.id);
      expect(game.carrier, castFor(sequence).finisher, reason: sequence.id);
    }
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
