/// **THE WHOLE SCRIPT, IN THE REAL APP, FROM A NEW SAVE.**
///
/// The other tutorial tests construct the state a step needs and drive the host
/// directly, which proves each beat works and says nothing about whether a
/// player can get from one to the next. This walks all nine, through
/// `MergeEmpireApp`, tapping only what a player can see — and it is the test
/// that would have caught the report it was written for.
///
/// **Three separate faults kept a first-time player at step 0 or step 1**, and
/// every one of them was invisible to a test that started mid-script:
///
/// 1. The DAILY REWARD sheet opened over the welcome card and absorbed every
///    tap on it. The card stayed visible throughout, so it read as the tutorial
///    being broken rather than as a sheet being in the way.
/// 2. `TutorialStep.condition` had no caller anywhere in `lib/`, so the three
///    steps that end by the player DOING something — scout one, scout three,
///    play a match — were each a dead end.
/// 3. A condition step's card was a modal, which ate the very tap the step was
///    waiting for.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/main.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/grid/loan_arrival.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

/// The app never settles — the diorama, the coach's ring and the pitch are all
/// animating — so `pumpAndSettle` would time out and every wait here has to
/// pump a fixed number of frames instead.
Future<void> beat(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// **PUMP UNTIL IT IS TRUE, not for a fixed count.** Boot fires real
/// asynchronous work off the platform channels — the stored session, the
/// store's catalogue, the connectivity watcher — and under load those land in
/// different frames, which moves when the tutorial's own post-frame callbacks
/// run. A fixed wait made this test pass alone and fail in a full suite, which
/// is the worst thing a guard can do: nobody trusts a flaky one.
/// **IT PUMPS BEFORE IT LOOKS, and that is not a detail.** Everything this
/// waits on is caused by a tap issued a line earlier, and a tap's `setState`
/// has not been built yet when it returns — so a predicate evaluated first
/// reads the state from BEFORE the action. That is how this test came to press
/// the scout button while the previous signing was still in flight: the widget
/// still said it was pressable, because the frame that would have said
/// otherwise had not been drawn.
Future<void> until(
  WidgetTester tester,
  bool Function() done, {
  String? reason,
  int frames = 60,
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (done()) return;
  }
  expect(done(), isTrue, reason: reason);
}

/// Is the scout button pressable right now?
///
/// It goes dead while a reveal is up, which is the guard that stops a second
/// signing landing on top of the first. A test that only asks whether the
/// button EXISTS taps it while it is inert and quietly does nothing.
bool _alive(WidgetTester tester) {
  final found = find.byKey(const ValueKey('add-player'));
  if (found.evaluate().isEmpty) return false;
  return tester.widget<InkWell>(found).onTap != null;
}

/// Is the spotlight's hole actually over [key] right now?
///
/// **Everything outside the hole is absorbed**, so this is not a cosmetic
/// question: until the overlay has measured the control, a tap on it lands on
/// the blocker and does nothing. It is also what a player waits for without
/// knowing it — the ring appearing round the thing they are being told to
/// press.
bool _holeOver(WidgetTester tester, String key) {
  final ring = find.byKey(const ValueKey('tutorial-ring'));
  final target = find.byKey(ValueKey(key));
  if (ring.evaluate().isEmpty || target.evaluate().isEmpty) return false;
  return tester.getRect(ring).contains(tester.getRect(target).center);
}

int stepOf(ProviderContainer c) =>
    (c.read(gameProvider).state!['tutorial'] as Map)['step'] as int;

Map<String, dynamic> tutorialOf(ProviderContainer c) =>
    c.read(gameProvider).state!['tutorial'] as Map<String, dynamic>;

int cardsOn(ProviderContainer c) =>
    ((c.read(gameProvider).state!['grid'] as Map)['cells'] as List)
        .where((cell) => cell != null)
        .length;

void main() {
  tearDown(resetPopupQueue);

  testWidgets('A NEW PLAYER CAN FINISH THE TUTORIAL', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          saveStoreProvider.overrideWithValue(
            MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const MergeEmpireApp();
          },
        ),
      ),
    );
    await until(
      tester,
      () => find.text(t('tut.welcome.title')).evaluate().isNotEmpty,
      reason: 'the welcome card never opened',
    );

    /// **WAIT FOR THE CONTROL, THEN PRESS IT.** The tab it lives on animates
    /// in and the scout reveal is a route over the top of it, so "it was there
    /// a moment ago" is not the same as "it is there now" — which is exactly
    /// the way this test used to fail in a full suite and pass on its own.
    Future<void> press(Finder finder, {String? reason}) async {
      await until(tester, () => finder.evaluate().isNotEmpty, reason: reason);
      await tester.tap(finder);
    }

    Future<void> answer(
      String labelKey,
      int expectedStep, {
      int frames = 60,
    }) async {
      await press(
        find.byKey(ValueKey('coach-action-$labelKey')),
        reason: 'no $labelKey to press',
      );
      await until(
        tester,
        () => stepOf(container) == expectedStep,
        frames: frames,
        reason: '$labelKey did not move the script on',
      );
    }

    // ── 0 · welcome ────────────────────────────────────────────────────────
    // **The sheet that broke it.** Nothing else may be over the card: the
    // daily reward used to open on top and swallow this tap.
    expect(find.byType(BottomSheet), findsNothing);
    expect(stepOf(container), 0);
    await answer('tut.welcome.btn', 1);

    // ── 1 · scout one ──────────────────────────────────────────────────────
    // A spotlight step, not a modal: the hole, the ring and the hand.
    await until(
      tester,
      () => find.byKey(const ValueKey('tutorial-hand')).evaluate().isNotEmpty,
      reason: 'no hand pointing at the scout button',
    );
    expect(find.byKey(const ValueKey('tutorial-spotlight')), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-ring')), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-hand')), findsOneWidget);

    /// One scout, start to finish: press the button THROUGH the hole, dismiss
    /// the reveal that lands over the top, and wait for the card to reach the
    /// grid. All three are one beat from the player's side.
    Future<void> scoutOne() async {
      final before = cardsOn(container);
      // **Wait for the HOLE, not just the button.** Between one step and the
      // next the overlay has nothing measured yet and blocks the whole screen,
      // which is right — a tap that landed then would be a tap the tutorial
      // was not ready for.
      await until(
        tester,
        () => _holeOver(tester, 'add-player') && _alive(tester),
        reason: 'the hole never landed on the scout button',
      );
      await tester.tap(find.byKey(const ValueKey('add-player')));
      // **The reveal is left to time itself out.** It holds the new card for a
      // beat and then dismisses itself; tapping it repeatedly re-entered the
      // skip and left the scout button's own in-flight guard stuck on, which
      // is a fault of the test rather than of the game.
      // **Wait for the BUTTON TO COME BACK, not for the card.** The signing
      // hits the save the instant the button is pressed — it is the reveal
      // that holds the card back from the grid — so "a card appeared" is true
      // a frame later and says nothing about whether the scout has finished.
      // The button is dead for as long as the reveal is up, which is exactly
      // the thing a player waits for.
      // **And the reveal has to be GONE, not merely finished.** Its overlay
      // lingers a frame past the future that resolves it, and a tap that lands
      // on the way out is a tap the scout never sees — which is the whole
      // reason this waits on three things rather than on a card appearing.
      await until(
        tester,
        () =>
            cardsOn(container) > before &&
            _alive(tester) &&
            find.byKey(const ValueKey('scout-reveal')).evaluate().isEmpty,
        frames: 200,
        reason: 'the scout never came back',
      );
      expect(
        cardsOn(container),
        greaterThan(before),
        reason: 'the scout never landed a card',
      );
    }

    // And the control it is pointing at takes the tap THROUGH the hole.
    await scoutOne();
    await until(
      tester,
      () => stepOf(container) == 2,
      reason: 'the condition did not move it on',
    );

    // ── 2 · scout three ────────────────────────────────────────────────────
    while (cardsOn(container) < 3) {
      await scoutOne();
    }
    await until(tester, () => stepOf(container) == 3);

    // ── 3 · the loan ───────────────────────────────────────────────────────
    // **LONGER, because the loan is WATCHED.** Each borrowed player drops into
    // the grid half a second behind the last and the script waits for the lot
    // — see `loanArrivalWindow`, which is what this budget has to cover.
    await answer(
      'tut.loan_boost.btn',
      4,
      frames: loanArrivalWindow(11).inMilliseconds ~/ 100 + 20,
    );
    expect(tutorialOf(container)['borrowedPlayersAdded'], isTrue);

    // ── 4 · go and play ────────────────────────────────────────────────────
    await answer('tut.play_match.btn', 5);

    // ── 5 · the match ──────────────────────────────────────────────────────
    // Pointed at the play button rather than modal over it, for the same
    // reason as the scout steps.
    await until(
      tester,
      () => _holeOver(tester, 'play-match'),
      reason: 'nothing was pointing at the play button',
    );
    expect(find.byKey(const ValueKey('tutorial-spotlight')), findsOneWidget);
    // The match itself is a screen of its own with a whole test file; what this
    // step waits on is the settled result, so that is what is put on the save.
    container.read(gameProvider).update((s) {
      final progression = s['progression'] as Map<String, dynamic>;
      progression['seasonAwardedPlayed'] = 1;
      progression['lastMatchResult'] = <String, dynamic>{
        'won': true,
        'score': '2-1',
      };
    });
    await until(tester, () => stepOf(container) == 6);

    // ── 6, 7, 8 · his reaction, the goodbye, the end ───────────────────────
    await answer('common.ok', 7);
    await answer('tut.loan_depart.btn', 8);
    expect(tutorialOf(container)['borrowedPlayersRemoved'], isTrue);
    await answer('tut.done.btn', 9);

    expect(tutorialOf(container)['done'], isTrue);
    // **And the queue is handed back.** The block is held for the whole script
    // and released at the end, so the daily reward the player has actually
    // earned finally opens rather than being stranded.
    expect(arePopupsBlocked(), isFalse);
    await beat(tester);
  });
}
