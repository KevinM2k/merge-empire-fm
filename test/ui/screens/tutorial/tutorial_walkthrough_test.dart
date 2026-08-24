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
import 'package:merge_empire_fc/main.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

/// The app never settles — the diorama, the coach's ring and the pitch are all
/// animating — so every wait here is a fixed number of frames rather than
/// `pumpAndSettle`, which would time out.
Future<void> beat(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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
    await beat(tester);

    /// The scout reveal is a route of its own and lands over whatever the
    /// tutorial has up. A player dismisses it and carries on; so does this.
    Future<void> clearReveal() async {
      if (find.byKey(const ValueKey('scout-reveal')).evaluate().isEmpty) return;
      await tester.tapAt(const Offset(210, 60));
      await beat(tester, 15);
    }

    Future<void> answer(String labelKey) async {
      await clearReveal();
      final button = find.byKey(ValueKey('coach-action-$labelKey'));
      expect(button, findsOneWidget, reason: 'no $labelKey to press');
      await tester.tap(button);
      await beat(tester);
    }

    // ── 0 · welcome ────────────────────────────────────────────────────────
    // **The sheet that broke it.** Nothing else may be over the card: the
    // daily reward used to open on top and swallow this tap.
    expect(find.byType(BottomSheet), findsNothing);
    expect(stepOf(container), 0);
    await answer('tut.welcome.btn');

    // ── 1 · scout one ──────────────────────────────────────────────────────
    expect(stepOf(container), 1);
    // A spotlight step, not a modal: the hole, the ring and the hand.
    expect(find.byKey(const ValueKey('tutorial-spotlight')), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-ring')), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-hand')), findsOneWidget);

    // And the control it is pointing at takes the tap THROUGH the hole.
    await tester.tap(find.byKey(const ValueKey('add-player')));
    await beat(tester, 20);
    expect(cardsOn(container), 1);
    expect(stepOf(container), 2, reason: 'the condition did not move it on');

    // ── 2 · scout three ────────────────────────────────────────────────────
    while (cardsOn(container) < 3) {
      await clearReveal();
      await tester.tap(find.byKey(const ValueKey('add-player')));
      await beat(tester, 20);
    }
    expect(stepOf(container), 3);

    // ── 3 · the loan ───────────────────────────────────────────────────────
    await answer('tut.loan_boost.btn');
    expect(stepOf(container), 4);
    expect(tutorialOf(container)['borrowedPlayersAdded'], isTrue);

    // ── 4 · go and play ────────────────────────────────────────────────────
    await answer('tut.play_match.btn');
    expect(stepOf(container), 5);

    // ── 5 · the match ──────────────────────────────────────────────────────
    // Pointed at the play button rather than modal over it, for the same
    // reason as the scout steps.
    expect(find.byKey(const ValueKey('tutorial-spotlight')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-match')), findsOneWidget);
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
    await beat(tester);
    expect(stepOf(container), 6);

    // ── 6, 7, 8 · his reaction, the goodbye, the end ───────────────────────
    await answer('common.ok');
    expect(stepOf(container), 7);
    await answer('tut.loan_depart.btn');
    expect(stepOf(container), 8);
    expect(tutorialOf(container)['borrowedPlayersRemoved'], isTrue);
    await answer('tut.done.btn');

    expect(tutorialOf(container)['done'], isTrue);
    // **And the queue is handed back.** The block is held for the whole script
    // and released at the end, so the daily reward the player has actually
    // earned finally opens rather than being stranded.
    expect(arePopupsBlocked(), isFalse);
    await beat(tester);
  });
}
