/// Every drill, in a window that is wide for its height.
///
/// **Reported from the couch: the training games look bad on a tablet held
/// landscape, and have to be scrolled.** Both halves of that are one fault.
/// Each drill is a board with a line or two of chrome over it, and each board
/// was built out of the WIDTH — Team Work's cards and Pitch Invaders' holes
/// were `Expanded` in a `Row`, so the tile was a fraction of however wide the
/// window happened to be and the board's height was then whatever that came
/// to. On a phone that is the same thing as building it out of a portrait
/// column. On a 1194pt window it is a 380pt tile and a board half again taller
/// than the page, which is why both of those two shipped inside a
/// `SingleChildScrollView`: it is what turns an overflow into a scroll.
///
/// So this file asks the two questions the couch asked, of all seven at once:
/// does the board fit inside the window, and is there anything to scroll. An
/// overflow fails a widget test on its own, which is the third.
///
/// The phone sizes are here for the other half of it — a fix for a tablet that
/// shrinks the board on a handset is not a fix — and they are what pins
/// [drillFrameAspect] down at both ends.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/minigames/boot_room_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/goalkeeper_practice_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/keepy_uppys_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigame_frame.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_view.dart';
import 'package:merge_empire_fc/ui/screens/minigames/pitch_invaders_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/teamwork_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/through_ball_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

/// A save with the Training Ground at the top of the ladder, so every drill
/// has its own difficulty rather than a default one.
Map<String, dynamic> saveWith() {
  final s = createDefaultState();
  (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.training] = {
    'owned': true,
    'tier': 6,
    'invested': 0,
    'tapCount': 0,
  };
  return s;
}

/// A tablet on its side. The iPad's own logical size, which is the window the
/// fault was reported on.
const Size tabletLandscape = Size(1194, 834);

/// A tablet upright, which is a wide window that is NOT wide for its height —
/// the cap has to leave this one nearly alone.
const Size tabletPortrait = Size(834, 1194);

const Size phonePortrait = Size(400, 880);

/// The hardest of the four: not wide enough to help and short enough that the
/// chrome very nearly fills it on its own.
const Size phoneLandscape = Size(880, 400);

const List<Size> everyWindow = [
  tabletLandscape,
  tabletPortrait,
  phonePortrait,
  phoneLandscape,
];

Future<ProviderContainer> pumpDrill(
  WidgetTester tester,
  Widget screen,
  Size window,
) async {
  tester.view.physicalSize = window * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

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
          home: screen,
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

/// Take the drill down before its timers are asked about.
Future<void> closeGame(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
}

/// **NOTHING TO SCROLL.** Not "does not scroll by default": a scroll view with
/// something under the fold is exactly the fault, and it looks identical to one
/// with nothing under it until you drag. Every scroll position in the tree has
/// to have no extent past the end of it.
void expectNothingToScroll(WidgetTester tester, String drill) {
  for (final state in tester.stateList<ScrollableState>(
    find.byType(Scrollable),
  )) {
    if (!state.position.hasContentDimensions) continue;
    expect(
      state.position.maxScrollExtent,
      0,
      reason: '$drill has ${state.position.maxScrollExtent}pt under the fold',
    );
  }
}

/// And the board is inside the window, which is the other half of it — a
/// `Column` can lay a child out past its own bottom edge without overflowing
/// if something between the two is not clipping.
void expectInsideWindow(
  WidgetTester tester,
  Finder finder,
  Size window,
  String what,
) {
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(-0.5), reason: '$what is off the top');
  expect(
    rect.bottom,
    lessThanOrEqualTo(window.height + 0.5),
    reason: '$what runs ${rect.bottom - window.height}pt off the bottom',
  );
  expect(rect.left, greaterThanOrEqualTo(-0.5), reason: '$what is off the left');
  expect(
    rect.right,
    lessThanOrEqualTo(window.width + 0.5),
    reason: '$what runs ${rect.right - window.width}pt off the right',
  );
}

/// The seven, and the part of each that has to be on screen.
final List<({String name, Widget Function() screen, Key board})> drills = [
  (
    name: 'Penalties',
    screen: PenaltyScreen.new,
    board: const ValueKey('penalty-view'),
  ),
  (
    name: 'Goalkeeper Practice',
    screen: GoalkeeperPracticeScreen.new,
    board: const ValueKey('train-stage'),
  ),
  (
    name: 'Keepy Uppys',
    screen: KeepyUppysScreen.new,
    board: const ValueKey('ku-arena'),
  ),
  (
    name: 'Through Ball',
    screen: ThroughBallScreen.new,
    // The LAST lane: the stack is built downwards, so the one that goes under
    // the fold first is the one at the bottom of it.
    board: const ValueKey('tb-lane-4'),
  ),
  (
    name: 'Pitch Invaders',
    screen: PitchInvadersScreen.new,
    board: const ValueKey('pi-board'),
  ),
  (
    name: 'Team Work',
    screen: TeamworkScreen.new,
    board: const ValueKey('pairs-board'),
  ),
  (
    name: 'Boot Room',
    screen: BootRoomScreen.new,
    board: const ValueKey('boot-room-board'),
  ),
];

void main() {
  tearDown(resetLocale);

  for (final drill in drills) {
    for (final window in everyWindow) {
      testWidgets(
        '${drill.name} fits ${window.width.round()}×${window.height.round()}',
        (tester) async {
          await pumpDrill(tester, drill.screen(), window);
          expect(
            find.byKey(drill.board),
            findsOneWidget,
            reason: '${drill.name} has no board',
          );
          expectInsideWindow(
            tester,
            find.byKey(drill.board),
            window,
            '${drill.name}\'s board',
          );
          expectNothingToScroll(tester, drill.name);
          await closeGame(tester);
        },
      );
    }
  }

  testWidgets('THE TILE KEEPS ITS SHAPE on a tablet held landscape', (
    tester,
  ) async {
    // The two boards whose tiles were a fraction of the width. A hole is
    // square and a card is 3:4 whatever the window is — a board that fits by
    // being squashed is not a board that fits.
    await pumpDrill(tester, const PitchInvadersScreen(), tabletLandscape);
    final hole = tester.getSize(find.byKey(const ValueKey('pi-hole-0')));
    expect(hole.width, closeTo(hole.height, 0.5), reason: 'the hole is not square');
    // And it is worth having: three of them plus the gutters and the board's
    // own inset are most of the frame the cap left.
    final board = tester.getSize(find.byKey(const ValueKey('pi-board')));
    expect(hole.width * 3, greaterThan(board.width * 0.9));
    await closeGame(tester);

    await pumpDrill(tester, const TeamworkScreen(), tabletLandscape);
    final card = tester.getSize(find.byKey(const ValueKey('pairs-tile-0')));
    expect(
      card.width / card.height,
      closeTo(pairsCardAspect, 0.01),
      reason: 'the card is not card-shaped',
    );
    await closeGame(tester);
  });

  testWidgets('THE PENALTY CAMERA KEEPS ITS LENS', (tester) async {
    // That drill is a scene rather than a board, and `_focalFor` answers a
    // view too wide for its height by opening the lens — which holds the shot
    // in frame and costs the goal its width. On a tablet held landscape it was
    // being handed the whole 1194, and the goal came out a small thing in a
    // lot of grass. Held to [penaltySceneAspect], the lens stays shut.
    await pumpDrill(tester, const PenaltyScreen(), tabletLandscape);
    final view = tester.getSize(find.byKey(const ValueKey('penalty-view')));
    expect(
      view.width / view.height,
      lessThanOrEqualTo(penaltySceneAspect + 0.01),
      reason: 'the lens has had to open, so the goal has lost width',
    );
    await closeGame(tester);
  });

  testWidgets('AND A PHONE IS LEFT ALONE', (tester) async {
    // The cap only engages on a window that is wide for its height. A handset
    // held upright is not one, and the board still takes the width it always
    // did — 0.72 of a phone's usable height is wider than the phone is.
    await pumpDrill(tester, const PitchInvadersScreen(), phonePortrait);
    final board = tester.getSize(find.byKey(const ValueKey('pi-board')));
    expect(
      board.width,
      greaterThan(phonePortrait.width - 40),
      reason: 'the cap has taken width off a phone',
    );
    await closeGame(tester);
  });

  test('the cap is a ceiling, a floor, and never more than there is', () {
    // A tablet on its side: the cap is what bites, and the surplus width is
    // margin.
    expect(
      drillFitWidth(const BoxConstraints(maxWidth: 1158, maxHeight: 778)),
      778 * drillFrameAspect,
    );
    // A phone held upright: taller than it is wide, so nothing happens to it.
    // This is the one that makes the cap safe to put under all seven.
    expect(
      drillFitWidth(const BoxConstraints(maxWidth: 388, maxHeight: 800)),
      388,
    );
    // A phone on its side: the cap would ask for 248, which is narrower than
    // any of these pages has ever been laid out at, so the floor answers.
    expect(
      drillFitWidth(const BoxConstraints(maxWidth: 844, maxHeight: 344)),
      drillFrameLeast,
    );
    // And the floor never invents width that is not there.
    expect(
      drillFitWidth(const BoxConstraints(maxWidth: 320, maxHeight: 344)),
      320,
    );
    // Nothing to work a width out from: the cap stands aside.
    expect(
      drillFitWidth(
        const BoxConstraints(
          minWidth: 500,
          maxWidth: 500,
          maxHeight: double.infinity,
        ),
      ),
      500,
    );
  });

  test('a board never comes out of drillTileWidth inside out', () {
    // A window with nothing left for the board is a board of nothing, not a
    // board of negative tiles — and the `Column` under it would throw.
    const nothing = BoxConstraints(maxWidth: 10, maxHeight: 0);
    expect(drillTileWidth(nothing, cols: 3, rows: 3, gap: 6), 0);
    // The smaller of the two answers, both ways round.
    const wide = BoxConstraints(maxWidth: 900, maxHeight: 300);
    expect(drillTileWidth(wide, cols: 3, rows: 3, gap: 6), (300 - 12) / 3);
    const tall = BoxConstraints(maxWidth: 300, maxHeight: 900);
    expect(drillTileWidth(tall, cols: 3, rows: 3, gap: 6), (300 - 12) / 3);
  });
}
