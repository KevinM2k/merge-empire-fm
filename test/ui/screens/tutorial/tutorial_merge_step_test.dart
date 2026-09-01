/// The merge step, and the drag cue that teaches it.
///
/// **The onboarding of a merge game never once asked the player to merge two
/// cards.** Measured on GA4 over August: 91% of new Android google-play/organic
/// users start the tutorial, 74% play a match, 59% finish it, and 26% ever open
/// the merge grid. See `docs/increase-retention.md`.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/tutorial_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/grid/merge_grid.dart';
import 'package:merge_empire_fc/ui/screens/tutorial/tutorial_overlay.dart';
import 'package:merge_empire_fc/ui/screens/tutorial/tutorial_spotlight.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

/// A save sitting on the merge step, with [defIds] on the grid.
Map<String, dynamic> onMergeStep(List<String> defIds) {
  final s = createDefaultState();
  (s['tutorial'] as Map<String, dynamic>)
    ..['step'] = tutorialSteps.indexWhere((t) => t.id == 'merge')
    ..['done'] = false;
  final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
  for (var i = 0; i < defIds.length; i++) {
    cells[i] = <String, dynamic>{
      'definitionId': defIds[i],
      'instanceId': 'c$i',
      'variant': 0,
    };
  }
  return s;
}


/// The grid and the script's overlay together, sitting on the merge step.
///
/// **Both, and that is the point.** Every other test of this step is pure Dart
/// or mounts one of the two, and the fault they all missed lives exactly at the
/// join: the cue measures a widget that belongs to the grid, and the grid takes
/// that widget out of the tree for the duration of a drag.
Future<ProviderContainer> pumpMergeStep(
  WidgetTester tester, {
  Map<int, String> cards = const {
    0: 'player_t1_mid',
    2: 'player_t1_mid',
  },
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final state = createDefaultState();
  final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List;
  cards.forEach((i, id) {
    cells[i] = <String, dynamic>{
      'definitionId': id,
      'instanceId': 'c$i',
      'variant': 0,
    };
  });

  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();
  // Through `load()`, then set by hand: a fixture with cards on the grid is a
  // played save and `settleTutorial` will have marked it finished.
  (container.read(gameProvider).state!['tutorial'] as Map<String, dynamic>)
    ..['step'] = tutorialSteps.indexWhere((t) => t.id == 'merge')
    ..['done'] = false;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const Scaffold(
            body: Stack(children: [MergeGrid(), TutorialHost()]),
          ),
        ),
      ),
    ),
  );
  // The cue never settles — it is a loop — so the frames are asked for by hand.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return container;
}

/// Every ring the cue has up, in the order it drew them.
///
/// By key prefix rather than by type, because `_Ring` is private to the
/// spotlight and should stay so — what this test is about is how MANY squares
/// are lit and where, which the keys carry.
List<Rect> ringRects(WidgetTester tester) {
  final found = find.byWidgetPredicate((w) {
    final key = w.key;
    return key is ValueKey<String> && key.value.startsWith('tutorial-ring');
  });
  return [
    for (var i = 0; i < found.evaluate().length; i++)
      tester.getRect(found.at(i)),
  ];
}

/// Pick a card up and hold it over another, leaving the finger DOWN.
Future<TestGesture> liftOnto(
  WidgetTester tester,
  Offset from,
  Offset to,
) async {
  final gesture = await tester.startGesture(from);
  // The card is handed over only once the hold has won — `delay: 200ms`.
  await tester.pump(const Duration(milliseconds: 400));
  await gesture.moveTo(to);
  await tester.pump(const Duration(milliseconds: 50));
  return gesture;
}

/// Every write arms the 2s debounced save; a test that walks away leaves it
/// pending and the binding rightly complains.
Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

List<String?> defsOn(ProviderContainer c) => [
  for (final cell in gridCells(c.read(gameProvider).state))
    cell is Map<String, dynamic> ? cell['definitionId'] as String? : null,
];

void main() {
  group('WHICH TWO CARDS THE CUE POINTS AT', () {
    /// The step named squares 0 and 2 — where the forced twin lands in the
    /// ordinary case, and only there. A twin forced onto the SECOND card makes
    /// the pair 0 and 1: the rings went round the wrong two and the hand mimed
    /// a drag that is a SWAP, so the player did what they were shown and
    /// nothing merged. Reported from the couch, twice.
    test('is the pair the GRID has, not a pair of fixed squares', () {
      expect(
        tutorialMergePair(
          onMergeStep(['player_t1_mid', 'player_t1_mid', 'player_t1_gk']),
        ),
        (from: 0, to: 1),
      );
      expect(
        tutorialMergePair(
          onMergeStep(['player_t1_mid', 'player_t1_gk', 'player_t1_mid']),
        ),
        (from: 0, to: 2),
      );
      expect(
        tutorialMergePair(
          onMergeStep(['player_t1_gk', 'player_t1_mid', 'player_t1_mid']),
        ),
        (from: 1, to: 2),
      );
    });

    test('and a board with no pair points at nothing', () {
      expect(
        tutorialMergePair(
          onMergeStep(['player_t1_mid', 'player_t1_gk', 'player_t1_def']),
        ),
        isNull,
      );
      expect(gridHasMergeablePair(onMergeStep(const [])), isFalse);
    });
  });

  /// **A DRAG THAT IS NOT THE MERGE DOES NOTHING.** The input seal is one
  /// rectangle and it has to hold both cards, so the squares between them are
  /// inside it too — and a drag onto one of those is a swap, which shuffles the
  /// board the step is pointing at out from under its own rings.
  group('SWAPPING IS OFF while the step is up', () {
    test('the rule is on for the merge step and nothing else', () {
      final s = onMergeStep(['player_t1_mid', 'player_t1_mid']);
      expect(tutorialMergeOnly(s), isTrue);

      final earlier = onMergeStep(['player_t1_mid', 'player_t1_mid']);
      (earlier['tutorial'] as Map<String, dynamic>)['step'] = 1;
      expect(tutorialMergeOnly(earlier), isFalse);

      final done = onMergeStep(['player_t1_mid', 'player_t1_mid']);
      (done['tutorial'] as Map<String, dynamic>)['done'] = true;
      expect(tutorialMergeOnly(done), isFalse);
      expect(tutorialMergeOnly(null), isFalse);
    });
  });

  group('THE HAND GRABS, CARRIES AND LETS GO', () {
    // It rose to a card and pressed it, which is the wrong instruction for the
    // one gesture in the game that starts on one thing and ends on another.
    const from = Offset(60, 200);
    const to = Offset(220, 200);
    const rest = Offset(60, 226);

    test('the fingertip reaches the first card, then travels to the second', () {
      expect(_DragProbe.tip(0, rest, from, to), rest);
      expect(_DragProbe.tip(dragGrabAt, rest, from, to), from);
      expect(_DragProbe.tip(dragCarryFrom, rest, from, to), from);
      // Half way across, and moving the right way.
      final mid = _DragProbe.tip(
        (dragCarryFrom + dragCarryTo) / 2,
        rest,
        from,
        to,
      );
      expect(mid.dx, greaterThan(from.dx));
      expect(mid.dx, lessThan(to.dx));
      expect(_DragProbe.tip(dragCarryTo, rest, from, to), to);
      // And it goes home for the next loop rather than teleporting.
      expect(_DragProbe.tip(1, rest, from, to), rest);
    });

    test('AND THE HAND IS A GRAB while it is carrying', () {
      // Asked for by name: it has to turn into a grab and back, or a hand
      // sliding across the screen is one pointing at things on its way past.
      expect(_DragProbe.grip(0), 0);
      expect(_DragProbe.grip(dragGrabAt), 0);
      expect(_DragProbe.grip(dragCarryFrom), 1);
      expect(_DragProbe.grip((dragCarryFrom + dragCarryTo) / 2), 1);
      // Open again on the release, and open by the time it is home.
      expect(_DragProbe.grip(1), 0);
    });

    test('and the beats are in order, inside one beat', () {
      expect(dragGrabAt, lessThan(dragCarryFrom));
      expect(dragCarryFrom, lessThan(dragCarryTo));
      expect(dragDropAt, dragCarryTo);
      expect(dragCarryTo, lessThan(1));
      // Longer than a tap, because it is four gestures rather than one.
      expect(dragCue, greaterThan(tapCue));
    });
  });

  /// **THE LAST CARD IS NOT A STEP.** It is the script saying it is over, and
  /// its only button finishes — a way out beside "well done" is a second way to
  /// answer it that costs the player the farewell the loan step just earned
  /// them, because `skipTutorial` deliberately does not pay one.
  group('THE LAST STEP HAS NO WAY OUT', () {
    test('and every step before it does', () {
      // A tutorial you cannot leave is a trap, and the JS puts the way out in
      // the corner of every step but this one.
      expect(tutorialSteps.last.id, 'done');
      expect(tutorialSteps.length, greaterThan(1));
    });

    test('and skipping never pays the farewell, wherever it is taken', () {
      final s = createDefaultState();
      (s['tutorial'] as Map<String, dynamic>)
        ..['step'] = tutorialSteps.length - 1
        ..['done'] = false;
      final cells = (s['grid'] as Map<String, dynamic>)['cells'] as List;
      cells[0] = <String, dynamic>{
        'definitionId': 'player_t1_mid',
        'instanceId': 'own',
        'variant': 0,
      };
      lendTutorialPlayers(s);
      final before =
          ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt();
      skipTutorial(s);
      expect(
        ((s['resources'] as Map<String, dynamic>)['fanCoins'] as num).toInt(),
        before,
      );
    });
  });

  group('NO EMOJI IN WHAT COLIN SAYS', () {
    test('the pictograph comes off, and the line is not left with a gap', () {
      expect(withoutEmoji('🔀 Hold & Drag to Merge'), 'Hold & Drag to Merge');
      expect(withoutEmoji('🏆 Cup won!'), 'Cup won!');
      expect(withoutEmoji('⭐ Star'), 'Star');
    });

    test('and the words are otherwise untouched', () {
      // An em dash is not an emoji, and a "×2" is a number.
      const line = 'Nakamura wants £12,500 — that is ×2 what we paid.';
      expect(withoutEmoji(line), line);
      expect(withoutEmoji("Don't sell him!"), "Don't sell him!");
    });

    test('a line that is nothing BUT emoji comes back empty', () {
      expect(withoutEmoji('🔀'), '');
      expect(withoutEmoji(''), '');
    });
  });

  /// **A CARD IN THE HAND STILL HAS A SQUARE.**
  ///
  /// Reported from the couch, as an asymmetry: picking the first card up left
  /// the second one dark, and picking the SECOND one up left the first one lit.
  /// There is no asymmetry in the merge — `mergeTargetsFor` and `attemptMerge`
  /// are symmetric in both indices — and there is none in the cue either. There
  /// is one null with two branches.
  ///
  /// The cue measured `grid-card-<index>`, which sits INSIDE the card's
  /// `LongPressDraggable.child`, and a Draggable swaps its child for
  /// `childWhenDragging` for the whole of a drag. So whichever card is in the
  /// hand cannot be measured:
  ///
  ///  - lift the FIRST and `target` goes null, which forces `dragTo` null too,
  ///    which leaves no hole at all — the screen goes dark AND `_blockersAround`
  ///    seals it with one full-screen `AbsorbPointer`, so the drop is never
  ///    delivered and the merge silently fails. That is the same report, worded
  ///    as "dragging the first card onto its twin does nothing".
  ///  - lift the SECOND and only `dragTo` goes null, so the hole shrinks back
  ///    to the first square, which stays lit while the second goes out.
  ///
  /// So the cue points at the SQUARE — `grid-slot-<index>`, the static layer
  /// the grid already paints under every filled cell — which no drag can take
  /// out of the tree.
  group('THE CUE HOLDS BOTH SQUARES WHILE A CARD IS IN HAND', () {
    testWidgets('lifting the FIRST card leaves both lit', (tester) async {
      await pumpMergeStep(tester);
      final from = tester.getCenter(find.byKey(const ValueKey('grid-card-0')));
      final to = tester.getCenter(find.byKey(const ValueKey('grid-card-2')));
      expect(ringRects(tester).length, 2, reason: 'both lit at rest');

      final gesture = await liftOnto(tester, from, to);
      addTearDown(() => gesture.up());

      final rings = ringRects(tester);
      expect(rings.length, 2, reason: 'the square it came from is still a square');
      final hole = rings.reduce((a, b) => a.expandToInclude(b));
      expect(hole.contains(from), isTrue);
      expect(hole.contains(to), isTrue);
    });

    testWidgets('and lifting the SECOND leaves both lit too', (tester) async {
      await pumpMergeStep(tester);
      final from = tester.getCenter(find.byKey(const ValueKey('grid-card-2')));
      final to = tester.getCenter(find.byKey(const ValueKey('grid-card-0')));

      final gesture = await liftOnto(tester, from, to);
      addTearDown(() => gesture.up());

      final rings = ringRects(tester);
      expect(rings.length, 2);
      final hole = rings.reduce((a, b) => a.expandToInclude(b));
      expect(hole.contains(from), isTrue);
      expect(hole.contains(to), isTrue);
    });
  });

  /// **AND THE DRAG THE STEP TEACHES ACTUALLY MERGES**, from either end.
  ///
  /// The whole of the step is one gesture, and it was never once driven through
  /// the real tree — which is how a cue that sealed the screen the instant the
  /// card left it shipped past a suite this size.
  group('THE MERGE ITSELF, THROUGH THE SEAL', () {
    for (final (name, from, to) in [
      ('the first card onto its twin', 0, 2),
      ('and the twin onto the first', 2, 0),
    ]) {
      testWidgets(name, (tester) async {
        final container = await pumpMergeStep(tester);
        final a = tester.getCenter(find.byKey(ValueKey('grid-card-$from')));
        final b = tester.getCenter(find.byKey(ValueKey('grid-card-$to')));

        final gesture = await liftOnto(tester, a, b);
        await gesture.up();
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await settleSave(tester);

        final defs = defsOn(container);
        expect(
          defs.where((d) => d == 'player_t1_mid'),
          isEmpty,
          reason: 'both tier ones are consumed by the merge',
        );
        expect(
          defs.whereType<String>().length,
          1,
          reason: 'and one card is left where they joined up',
        );
      });
    }
  });
}

/// The cue's arithmetic, reached through the library's own names.
///
/// `_DragHand` is private to the spotlight — the widget is, and should be — so
/// the two static solves it is built out of are exercised through this rather
/// than by making the widget public for a test.
class _DragProbe {
  static Offset tip(double t, Offset rest, Offset from, Offset to) =>
      dragTipAt(t, rest, from, to);
  static double grip(double t) => dragGripAt(t);
}
