/// Pitch Invaders.
///
/// `recordWhackResult`, `whackDifficulty` and `whackMaxCatches` have been
/// ported and tested since M1 — including the clean-sheet counter a season
/// quest reads — and there was no board to play on. Ten catalogues carry
/// `game.whack.instructions`, `.caught`, `.caught_label`, `.fouls`, `.clean`
/// and `.full_time` with nothing able to reach one.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/mini_games.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigame_countdown.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/screens/minigames/pitch_invaders_screen.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic> saveWith() {
  final s = createDefaultState();
  // Tier 4 Training Ground, the rung Pitch Invaders sits on.
  (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.training] = {
    'owned': true,
    'tier': 4,
    'invested': 0,
    'tapCount': 0,
  };
  return s;
}

/// The clock the screen's deadline is read against, moved by the test rather
/// than by the wall — `now()` is the port's `Date.now()` and the seam every
/// engine's timestamps already go through.
late int fakeNow;

Future<ProviderContainer> pumpGame(WidgetTester tester) async {
  // A phone-shaped, TALL surface. On the default 800x600 the nine-hole board
  // runs off the bottom, and a tap on a hole below the fold silently hits the
  // view instead.
  tester.view.physicalSize = const Size(420 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  fakeNow = DateTime.utc(2026, 3, 1).millisecondsSinceEpoch;
  setClock(() => fakeNow);
  addTearDown(resetClock);

  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(saveWith())}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const PitchInvadersScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// Advance both clocks together. The fake async clock drives the spawn timers
/// and the ticker; `now()` drives the deadline, and if the two drift apart the
/// session either never ends or ends immediately.
Future<void> advance(WidgetTester tester, int ms) async {
  const step = 16;
  for (var moved = 0; moved < ms; moved += step) {
    fakeNow += step;
    await tester.pump(const Duration(milliseconds: step));
  }
}

PitchInvadersScreenState stateOf(WidgetTester tester) =>
    tester.state<PitchInvadersScreenState>(find.byType(PitchInvadersScreen));

Future<void> closeGame(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
}

void main() {
  tearDown(resetLocale);

  group('what pops up', () {
    test('is STEWARD, then dog, then invader — the bands, in order', () {
      // The order decides which band a roll lands in, so it is the order and
      // not just the three numbers that has to match.
      expect(pickInvader(0.0, 0.12, 0.08), Invader.steward);
      expect(pickInvader(0.119, 0.12, 0.08), Invader.steward);
      expect(pickInvader(0.12, 0.12, 0.08), Invader.dog);
      expect(pickInvader(0.199, 0.12, 0.08), Invader.dog);
      expect(pickInvader(0.2, 0.12, 0.08), Invader.invader);
      expect(pickInvader(1.0, 0.12, 0.08), Invader.invader);
    });

    test('and the dog is worth three while a steward costs one', () {
      expect(Invader.invader.value, 1);
      expect(Invader.dog.value, Whack.dogValue);
      expect(Invader.steward.value, -Whack.foulCost);
    });

    test('stewards get commoner as you climb; the dog never does', () {
      final sunday = whackDifficulty(0);
      final champions = whackDifficulty(6);
      expect(champions.stewardPct, greaterThan(sunday.stewardPct));
      expect(champions.dogPct, sunday.dogPct);
      expect(champions.spawnMs, lessThan(sunday.spawnMs));
      expect(champions.upMs, lessThan(sunday.upMs));
    });
  });

  testWidgets('the drill is REACHABLE — it is in the playable set', (
    tester,
  ) async {
    expect(playableMiniGames, contains(MiniGameKind.whack));
  });

  testWidgets('THE COUNT COMES FIRST, and nothing pops before GO', (
    tester,
  ) async {
    // **THE LEAD-IN IS THE 3-2-1 NOW**, not the JS's silent 600ms — see
    // `minigame_countdown.dart`. `Whack.leadInMs` is still pinned against the
    // JS in `mini_games_test.dart`; what the SCREEN waits for is the count.
    await pumpGame(tester);
    await advance(tester, miniGameCountdownMs - 100);
    final s = stateOf(tester);
    expect(s.running, isFalse, reason: 'the session started early');
    expect(s.holes.every((h) => h == null), isTrue);

    await advance(tester, 200);
    expect(stateOf(tester).running, isTrue);
    await closeGame(tester);
  });

  testWidgets('entering does not spend the attempt — KICK-OFF does', (
    tester,
  ) async {
    // Walking out during the lead-in has cost nothing, so the cooldown must
    // not have started.
    final container = await pumpGame(tester);
    await advance(tester, miniGameCountdownMs - 100);
    expect(
      miniGameReady(container.read(gameProvider).state!, MiniGameKind.whack),
      isTrue,
    );

    await advance(tester, 200);
    expect(
      miniGameReady(container.read(gameProvider).state!, MiniGameKind.whack),
      isFalse,
    );
    await closeGame(tester);
  });

  testWidgets('an INVADER is a catch and a STEWARD is a foul', (tester) async {
    await pumpGame(tester);
    await advance(tester, miniGameCountdownMs + 100);
    final s = stateOf(tester);

    // Wait for something to be up, then tap whatever it is and check the
    // counter moved the way that thing should move it.
    var caught = 0;
    var fouls = 0;
    for (var i = 0; i < 40 && (caught == 0 || fouls == 0); i++) {
      final upIndex = s.holes.indexWhere((h) => h != null);
      if (upIndex >= 0) {
        final what = s.holes[upIndex]!;
        final before = s.catches;
        await tester.tap(find.byKey(ValueKey('pi-hole-$upIndex')));
        await tester.pump();
        switch (what) {
          case Invader.steward:
            fouls++;
            expect(s.catches, lessThanOrEqualTo(before));
            expect(s.fouls, fouls);
          case Invader.dog:
            caught++;
            expect(s.catches, before + Whack.dogValue);
          case Invader.invader:
            caught++;
            expect(s.catches, before + 1);
        }
      }
      await advance(tester, 100);
    }
    expect(caught, greaterThan(0), reason: 'nothing was ever catchable');
    await closeGame(tester);
  });

  testWidgets('a tapped hole is EMPTY — it cannot be farmed twice', (
    tester,
  ) async {
    await pumpGame(tester);
    await advance(tester, miniGameCountdownMs + 100);
    final s = stateOf(tester);
    var index = -1;
    for (var i = 0; i < 40 && index < 0; i++) {
      index = s.holes.indexWhere((h) => h != null);
      if (index < 0) await advance(tester, 100);
    }
    expect(index, greaterThanOrEqualTo(0));

    await tester.tap(find.byKey(ValueKey('pi-hole-$index')));
    await tester.pump();
    final after = s.catches;
    expect(s.holes[index], isNull);
    await tester.tap(find.byKey(ValueKey('pi-hole-$index')));
    await tester.pump();
    expect(s.catches, after, reason: 'an empty hole paid a second time');
    await closeGame(tester);
  });

  testWidgets('THE CLOCK IS A DEADLINE, not a countdown', (tester) async {
    // A phone that backgrounds the app for five seconds and comes back gets
    // the right time remaining rather than five free seconds. Here the frames
    // stop and the clock does not, which is exactly that.
    await pumpGame(tester);
    await advance(tester, miniGameCountdownMs + 100);
    final s = stateOf(tester);
    expect(s.over, isFalse);

    fakeNow += Whack.durationMs;
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      s.over,
      isTrue,
      reason: 'the session survived its own deadline passing',
    );
    await closeGame(tester);
  });

  testWidgets('full time empties the board and offers the reward', (
    tester,
  ) async {
    final container = await pumpGame(tester);
    await advance(tester, miniGameCountdownMs + 100);
    final s = stateOf(tester);
    fakeNow += Whack.durationMs;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpAndSettle();

    expect(s.holes.every((h) => h == null), isTrue);
    expect(find.byKey(const ValueKey('pi-outcome')), findsOneWidget);
    expect(find.byKey(const ValueKey('pi-caught')), findsOneWidget);

    final before =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    await tester.tap(find.byKey(const ValueKey('pi-collect')));
    await tester.pump();
    final after =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    expect(after - before, s.coinsWon);
    await tester.pumpAndSettle();
    await closeGame(tester);
  });

  testWidgets('LEAVING BEFORE KICK-OFF banks nothing at all', (tester) async {
    final container = await pumpGame(tester);
    await advance(tester, miniGameCountdownMs - 100);
    final before = jsonEncode(container.read(gameProvider).state!['stats']);
    await closeGame(tester);
    expect(
      jsonEncode(container.read(gameProvider).state!['stats']),
      before,
      reason: 'a session that never kicked off was counted',
    );
  });

  testWidgets('but leaving MID-SESSION banks it, once', (tester) async {
    final container = await pumpGame(tester);
    await advance(tester, miniGameCountdownMs + 100);
    final s = stateOf(tester);
    for (var i = 0; i < 30; i++) {
      final index = s.holes.indexWhere((h) => h != null);
      if (index >= 0 && s.holes[index] != Invader.steward) {
        await tester.tap(find.byKey(ValueKey('pi-hole-$index')));
        await tester.pump();
      }
      if (s.catches > 0) break;
      await advance(tester, 100);
    }
    expect(s.catches, greaterThan(0));

    final before =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    await closeGame(tester);
    final after =
        (container.read(gameProvider).state!['resources']
                as Map<String, dynamic>)['fanCoins']
            as num;
    expect(after, greaterThan(before));
    expect(
      (container.read(gameProvider).state!['stats']
          as Map<String, dynamic>)['whackRounds'],
      1,
      reason: 'the session was counted twice',
    );
  });

  testWidgets('EVERY HOLE IS THE SAME SIZE', (tester) async {
    // The gutter was `Padding(left: 8)` INSIDE each `Expanded`, so the first
    // column's tile was eight points narrower... on every column but the first.
    // The tile is an `AspectRatio`, so it was eight points shorter as well.
    // Reported as the left boxes being bigger than the rest.
    await pumpGame(tester);
    final sizes = [
      for (var i = 0; i < 9; i++)
        tester.getSize(find.byKey(ValueKey('pi-hole-$i'))),
    ];
    for (final size in sizes) {
      expect(size.width, closeTo(sizes.first.width, 0.5));
      expect(size.height, closeTo(sizes.first.height, 0.5));
    }
  });

  testWidgets('THE MOUTH IS AN ELLIPSE, not a disc in a square of grass', (
    tester,
  ) async {
    // **`BoxShape.circle` was the whole of "it does not look like a hole".**
    // The spec's `.pi-mouth` is a box 76% wide and 40% tall at
    // `border-radius: 50%`, which in CSS is an ellipse FILLING it. Flutter's
    // circle is a disc of the box's shortest side, centred — so the mouth was a
    // small round coin in the middle of the tile, and the earlier pass that
    // widened the box from 12% inset to 5% changed nothing at all, because a
    // circle does not care how wide its box is.
    await pumpGame(tester);
    final tile = tester.getSize(find.byKey(const ValueKey('pi-hole-0')));
    final mouth = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byKey(const ValueKey('pi-hole-0')),
            matching: find.byType(DecoratedBox),
          ),
        )
        .where((box) => box.decoration is ShapeDecoration)
        .toList();
    expect(mouth, isNotEmpty, reason: 'the mouth is not a shape at all');
    for (final box in mouth) {
      expect((box.decoration as ShapeDecoration).shape, isA<OvalBorder>());
    }
    // And the box it fills is wider than it is tall, or the oval is a circle
    // again by another route.
    final rect = tester.getRect(
      find
          .descendant(
            of: find.byKey(const ValueKey('pi-hole-0')),
            matching: find.byWidgetPredicate(
              (w) => w is DecoratedBox && w.decoration is ShapeDecoration,
            ),
          )
          .first,
    );
    expect(rect.width, greaterThan(rect.height * 1.5));
    expect(rect.width, lessThan(tile.width));
  });

  testWidgets('HE COMES OUT OF THE HOLE, and only his feet are behind it', (
    tester,
  ) async {
    // **THE HOLE WAS DRAWN OVER A QUARTER OF HIM.** `upBottom` was fed straight
    // to an `Align`, whose y positions the glyph's BOX in the space left over
    // rather than putting its bottom edge anywhere — so the figure sat a sixth
    // of a tile lower than the constant claimed and the near half of the mouth
    // was painted across his shins. What that reads as is the hole being in
    // front of the thing in it. Reported from the couch in those words.
    await pumpGame(tester);
    await advance(tester, miniGameCountdownMs + 100);
    final s = stateOf(tester);
    var up = -1;
    for (var i = 0; i < 60 && up < 0; i++) {
      up = s.holes.indexWhere((h) => h != null);
      if (up < 0) await advance(tester, 100);
    }
    expect(up, greaterThanOrEqualTo(0), reason: 'nothing ever came up');
    await advance(tester, 200);

    final tile = tester.getRect(find.byKey(ValueKey('pi-hole-$up')));
    final figure = tester.getRect(find.byKey(ValueKey('pi-figure-$up')));
    // The occluder — the turf band and the mouth's near half over it — starts
    // at the mouth's waist, measured from the tile's bottom.
    final waist = tile.bottom - occludeTop * tile.height;
    final hidden = (figure.bottom - waist) / figure.height;

    expect(
      hidden,
      greaterThan(0),
      reason: 'nothing of him is behind the rim — he is standing ON the grass',
    );
    expect(
      hidden,
      lessThan(0.15),
      reason: 'the near rim is across his shins rather than his ankles',
    );
    // And most of him is above the hole's own top edge, which is what "out of
    // it" looks like.
    final rim = tile.bottom - (mouthBottom + mouthHeight) * tile.height;
    expect((rim - figure.top) / figure.height, greaterThan(0.5));
    await closeGame(tester);
  });

  testWidgets('AND NOTHING IS PAINTED OVER HIM — the hole is BEHIND', (
    tester,
  ) async {
    // **Reported from the couch: "the hole is in front of the item coming out
    // of it. The item needs to be in front of the hole."** It was: the tile
    // carried a full-width turf band at the mouth's waist, drawn AFTER the
    // figure, so the thing that actually cut him was a straight horizontal edge
    // across his shins — with the arc that was supposed to do it sitting
    // harmlessly underneath. The cut is a clip on the figure now, so the hole
    // is drawn once and drawn first.
    await pumpGame(tester);
    await advance(tester, miniGameCountdownMs + 100);
    final s = stateOf(tester);
    var up = -1;
    for (var i = 0; i < 60 && up < 0; i++) {
      up = s.holes.indexWhere((h) => h != null);
      if (up < 0) await advance(tester, 100);
    }
    expect(up, greaterThanOrEqualTo(0), reason: 'nothing ever came up');
    await advance(tester, 200);

    final hole = find.byKey(ValueKey('pi-hole-$up'));
    // He is cut by a CLIP, which is the whole of the fix.
    final clip = find.descendant(of: hole, matching: find.byType(ClipPath));
    expect(clip, findsOneWidget);
    expect(
      find.descendant(
        of: clip,
        matching: find.byKey(ValueKey('pi-figure-$up')),
      ),
      findsOneWidget,
      reason: 'the figure is not the thing being clipped',
    );
    // And he is the last of the SCENE in the tile's stack, so there is nothing
    // of the hole left to paint over him. The one layer after him is the tap
    // ring, which is a frame round the whole tile rather than part of the hole
    // and is meant to be over the top — see `whackFlash`.
    final stack = tester.widget<Stack>(
      find.descendant(of: hole, matching: find.byType(Stack)).first,
    );
    final figure = stack.children.indexWhere(
      (c) => c is Positioned && c.child is ClipPath,
    );
    expect(figure, greaterThanOrEqualTo(0), reason: 'the figure is not clipped');
    expect(
      stack.children.length - figure,
      2,
      reason: 'something of the scene is drawn after the figure',
    );
    expect(
      find.descendant(
        of: hole,
        matching: find.byKey(ValueKey('pi-flash-$up')),
      ),
      findsOneWidget,
    );
    await closeGame(tester);
  });

  testWidgets('AND YOU CANNOT SEE HIM THROUGH THE GRASS EITHER SIDE OF IT', (
    tester,
  ) async {
    // **Reported from the couch: "they go through the hole ok but you see them
    // under the hole."** The clip took ONE bite below the ground plane — the
    // mouth's lower half-ellipse — and left the rest of that band alone: the
    // two lunes inside the mouth's box either side of the arc, and the strips
    // of plain turf outside it. All of that is ground in FRONT of the hole, so
    // a figure ducking slid down through it in full view.
    //
    // The rule is one sentence and this is it: below the waist, the only thing
    // visible is what is inside the mouth.
    await pumpGame(tester);
    await advance(tester, miniGameCountdownMs + 100);
    final s = stateOf(tester);
    var up = -1;
    for (var i = 0; i < 60 && up < 0; i++) {
      up = s.holes.indexWhere((h) => h != null);
      if (up < 0) await advance(tester, 100);
    }
    expect(up, greaterThanOrEqualTo(0), reason: 'nothing ever came up');
    await advance(tester, 200);

    final hole = find.byKey(ValueKey('pi-hole-$up'));
    final clipPath = tester.widget<ClipPath>(
      find.descendant(of: hole, matching: find.byType(ClipPath)),
    );
    final tile = tester.getRect(hole);
    final size = tile.size;
    final path = clipPath.clipper!.getClip(size);
    Offset at(double fx, double fy) =>
        Offset(size.width * fx, size.height * fy);

    // The ground plane: the mouth's widest line.
    const waist = 1 - mouthBottom - mouthHeight / 2;

    expect(
      path.contains(at(0.5, waist - 0.1)),
      isTrue,
      reason: 'he is cut off above the ground, standing in a trench',
    );
    // Down the middle of the mouth, below the waist — you are looking INTO the
    // hole, so he is visible there and the cut follows the arc.
    expect(
      path.contains(at(0.5, waist + 0.05)),
      isTrue,
      reason: 'the cut is a straight chord across the mouth, not the rim',
    );
    // Plain turf beside the hole, at the same height. This was always right.
    expect(
      path.contains(at(0.02, waist + 0.05)),
      isFalse,
      reason: 'he is showing on the grass beside the hole',
    );
    // **THE LUNE**, which is the one that was reported: inside the mouth's own
    // box, below the waist, outside the ellipse. At this depth the arc has
    // narrowed to about the middle two fifths of the tile, so a fifth in from
    // the left is turf.
    expect(
      path.contains(at(0.20, 1 - mouthBottom - 0.03)),
      isFalse,
      reason: 'he is showing under the hole, either side of the near rim',
    );
    expect(
      path.contains(at(0.80, 1 - mouthBottom - 0.03)),
      isFalse,
      reason: 'he is showing under the hole, either side of the near rim',
    );
    // And nothing below the mouth at all, so a duck takes him out of sight.
    expect(path.contains(at(0.5, 0.99)), isFalse);
    await closeGame(tester);
  });

  testWidgets('AND A TILE IS MOST OF THE WIDTH IT CAN BE', (tester) async {
    // A tile is a target you have seven hundred milliseconds to hit, and the
    // board was sharing what the instructions, the score row and the timer left
    // over. Asked for twice.
    await pumpGame(tester);
    final board = tester.getSize(find.byKey(const ValueKey('pi-board')));
    final tile = tester.getSize(find.byKey(const ValueKey('pi-hole-0')));
    // Three across two gutters: the tile cannot be more than a third, and it
    // should not be much less.
    expect(tile.width, greaterThan(board.width / 3 - 6));
    expect(tile.width * 3, greaterThan(board.width * 0.9));
  });

  group('A TAP GETS AN ANSWER ON THE TILE', () {
    test('THE DOG IS GOLD and a STEWARD IS RED', () {
      // Three readings, not one — that is the whole point of the feedback. The
      // man is the club's own accent, so a catch is drawn in the kit; the dog
      // is the gold every bonus in the game wears, which is what makes the
      // rarer, bigger catch land harder; the steward is the red a goal against
      // is drawn in, because it is the one tap that took something away.
      //
      // **A UNIT TEST, because the dog is a rarer draw than a session is
      // long.** An integration test that waits for one fails on a bad roll.
      const kit = KitTheme(
        bg: Color(0xFF000000),
        surface: Color(0xFF111111),
        surface2: Color(0xFF222222),
        border: Color(0xFF333333),
        textMuted: Color(0xFF888888),
        accent: Color(0xFF00A0FF),
        accentBright: Color(0xFF40D0FF),
        accentBrightInk: Color(0xFF000000),
        accentInk: Color(0xFFFFFFFF),
        background: BoxDecoration(color: Color(0xFF000000)),
      );
      expect(whackFlashInk(kit, Invader.invader), kit.accentBright);
      expect(whackFlashInk(kit, Invader.dog), whackDogInk);
      // The palette's own danger, not a red this screen invented.
      expect(whackFlashInk(kit, Invader.steward), dangerInk);
      // And no two of them are the same colour, which is the requirement.
      expect(
        {
          for (final what in Invader.values) whackFlashInk(kit, what),
        },
        hasLength(Invader.values.length),
      );
    });

    // **The board said nothing back.** The figure dropped, a number at the top
    // of the page moved, and nothing where the player was actually looking
    // told them which of the three things they had just hit. Asked for from
    // the couch, in three colours: the man, the better one, and the mistake.
    Future<int> waitForOne(
      WidgetTester tester,
      PitchInvadersScreenState s, {
      required bool Function(Invader) want,
    }) async {
      for (var i = 0; i < 200; i++) {
        final index = s.holes.indexWhere((h) => h != null && want(h));
        if (index >= 0) return index;
        await advance(tester, 60);
      }
      return -1;
    }

    Future<Color?> ringInk(WidgetTester tester, int index) async {
      final box = tester.widget<AnimatedContainer>(
        find.byKey(ValueKey('pi-flash-$index')),
      );
      final decoration = box.decoration! as BoxDecoration;
      return decoration.border?.top.color;
    }

    testWidgets('and NOTHING is ringed before a tap', (tester) async {
      await pumpGame(tester);
      await advance(tester, miniGameCountdownMs + 100);
      for (var i = 0; i < Whack.holes; i++) {
        expect(await ringInk(tester, i), Colors.transparent);
      }
      expect(stateOf(tester).flashes, isEmpty);
      await closeGame(tester);
    });

    testWidgets('a MAN rings the tile in the club\'s own accent', (
      tester,
    ) async {
      await pumpGame(tester);
      await advance(tester, miniGameCountdownMs + 100);
      final s = stateOf(tester);
      final index = await waitForOne(
        tester,
        s,
        want: (h) => h == Invader.invader,
      );
      expect(index, greaterThanOrEqualTo(0), reason: 'no invader ever came up');
      await tester.tap(find.byKey(ValueKey('pi-hole-$index')));
      await tester.pump();

      expect(s.flashes[index], Invader.invader);
      final kit = Theme.of(
        tester.element(find.byKey(const ValueKey('pi-board'))),
      ).extension<KitTheme>()!;
      expect(await ringInk(tester, index), kit.accentBright);
      expect(await ringInk(tester, (index + 1) % Whack.holes), Colors.transparent,
          reason: 'the ring is on the wrong tile, or on all of them');
      await closeGame(tester);
    });

    testWidgets('and the ring comes back down on its own', (tester) async {
      // Otherwise the next pop-up into that hole arrives wearing the last
      // tap's answer.
      await pumpGame(tester);
      await advance(tester, miniGameCountdownMs + 100);
      final s = stateOf(tester);
      final index = await waitForOne(tester, s, want: (_) => true);
      expect(index, greaterThanOrEqualTo(0));
      await tester.tap(find.byKey(ValueKey('pi-hole-$index')));
      await tester.pump();
      expect(s.flashes.containsKey(index), isTrue);

      await advance(tester, whackFlash.inMilliseconds + 100);
      expect(s.flashes.containsKey(index), isFalse);
      await closeGame(tester);
    });

    testWidgets('and full time takes every ring down with the board', (
      tester,
    ) async {
      await pumpGame(tester);
      await advance(tester, miniGameCountdownMs + 100);
      final s = stateOf(tester);
      final index = await waitForOne(tester, s, want: (_) => true);
      expect(index, greaterThanOrEqualTo(0));
      await tester.tap(find.byKey(ValueKey('pi-hole-$index')));
      await tester.pump();
      expect(s.flashes, isNotEmpty);

      fakeNow += Whack.durationMs;
      await tester.pump(const Duration(milliseconds: 16));
      expect(s.over, isTrue);
      expect(s.flashes, isEmpty, reason: 'a ring outlived the session');
      await tester.pumpAndSettle();
      await closeGame(tester);
    });
  });

  group('THE COUNT IN', () {
    testWidgets('is 3, 2, 1 and then GO', (tester) async {
      await pumpGame(tester);
      // **WATCHED RATHER THAN CLOCKED.** Each beat is restarted on the frame
      // the last one finished, so advancing exactly `countdownBeatMs` lands a
      // frame either side of the change; what the test is about is the order
      // of the four, and that nothing is running behind them.
      final seen = <String>[];
      for (var i = 0; i < 300; i++) {
        for (final label in [...countdownBeats, 'go']) {
          final found = find
              .byKey(ValueKey('mg-countdown-$label'))
              .evaluate()
              .isNotEmpty;
          if (found && (seen.isEmpty || seen.last != label)) seen.add(label);
        }
        if (!stateOf(tester).counting) break;
        expect(stateOf(tester).running, isFalse, reason: 'it started early');
        await advance(tester, 60);
      }
      expect(seen, [...countdownBeats, 'go']);

      await advance(tester, 100);
      expect(stateOf(tester).counting, isFalse);
      expect(stateOf(tester).running, isTrue, reason: 'GO did not kick off');
      expect(find.byKey(const ValueKey('mg-countdown-go')), findsNothing);
      expect(find.text(t('mg.countdown_go')), findsNothing);
      await closeGame(tester);
    });

    testWidgets('AND THE BOARD IS BEHIND IT, not replaced by it', (
      tester,
    ) async {
      // Three seconds of an empty page is three seconds of not knowing what is
      // about to be asked of you.
      await pumpGame(tester);
      expect(stateOf(tester).counting, isTrue);
      expect(find.byKey(const ValueKey('pi-board')), findsOneWidget);
      expect(find.byKey(const ValueKey('pi-hole-4')), findsOneWidget);
      await closeGame(tester);
    });

    testWidgets('and leaving during it banks nothing — GO spends the attempt', (
      tester,
    ) async {
      final container = await pumpGame(tester);
      await advance(tester, countdownBeatMs);
      expect(
        miniGameReady(container.read(gameProvider).state!, MiniGameKind.whack),
        isTrue,
        reason: 'the count spent the session',
      );
      await closeGame(tester);
    });
  });
}
