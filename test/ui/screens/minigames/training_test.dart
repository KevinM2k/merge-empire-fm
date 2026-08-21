/// The Training tab and Penalty Training.
///
/// The tab was a stub while the Club's Training Ground unlocked games it
/// pointed at — two dangling references at once.
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
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/engine/penalty_physics.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_screen.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_view.dart';
import 'package:merge_empire_fc/ui/screens/minigames/training_view.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Map<String, dynamic> saveWith({int trainingTier = 0, bool onCooldown = false}) {
  final s = createDefaultState();
  if (trainingTier > 0) {
    (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.training] = {
      'owned': true,
      'tier': trainingTier,
      'invested': 0,
      'tapCount': 0,
    };
  }
  if (onCooldown) {
    s['miniGames'] = <String, dynamic>{
      'penaltyLastPlayed': DateTime.now().millisecondsSinceEpoch,
    };
  }
  return s;
}

Future<ProviderContainer> pumpTraining(
  WidgetTester tester,
  Map<String, dynamic> state,
) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
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
          // The keeper shifts his weight on a loop while he waits, so
          // `pumpAndSettle` would never settle. He honours reduce-motion;
          // declaring it here is what a device with that setting on would do —
          // the same thing the home screen's walker needs.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const Scaffold(body: TrainingView()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));

void main() {
  tearDown(resetLocale);

  group('the drills list', () {
    testWidgets('shows every game the catalogue has', (tester) async {
      await pumpTraining(tester, saveWith());
      for (final kind in miniGameTitleKeys.keys) {
        expect(
          find.byKey(ValueKey('training-$kind'), skipOffstage: false),
          findsOneWidget,
          reason: kind,
        );
      }
    });

    testWidgets('the Training Ground unlocks them a tier at a time', (
      tester,
    ) async {
      final none = await pumpTraining(tester, saveWith());
      final locked = none
          .read(miniGamesProvider)
          .where((g) => !g.unlocked)
          .length;

      final built = await pumpTraining(tester, saveWith(trainingTier: 6));
      expect(
        built.read(miniGamesProvider).where((g) => !g.unlocked).length,
        lessThan(locked),
      );
    });

    testWidgets('penalty is open from the start', (tester) async {
      // It is the one game that needs no facility at all.
      final container = await pumpTraining(tester, saveWith());
      final penalty = container
          .read(miniGamesProvider)
          .firstWhere((g) => g.kind == MiniGameKind.penalty);
      expect(penalty.unlocked, isTrue);
      expect(penalty.playable, isTrue);
      expect(penalty.ready, isTrue);
    });

    testWidgets('EVERY GAME IN THE LIST NOW LEADS SOMEWHERE', (tester) async {
      // Listing one that leads nowhere is the bug this whole tab replaced, and
      // for most of the port five of the seven did exactly that — the tier
      // unlocked a drill with no screen behind it. All seven are built now, so
      // "coming soon" must not appear at all.
      final container = await pumpTraining(tester, saveWith(trainingTier: 6));
      final unbuilt = container
          .read(miniGamesProvider)
          .where((g) => g.unlocked && !g.playable);
      expect(unbuilt, isEmpty, reason: 'a row still leads nowhere');
      expect(find.text(t('settings.comingSoon')), findsNothing);
      // And the guard stays: a kind added to the catalogue ahead of its screen
      // is what `playable` is for, so the two lists have to agree.
      expect(playableMiniGames, hasLength(miniGameTitleKeys.length));
    });

    testWidgets('a rested game says how long, not just no', (tester) async {
      final container = await pumpTraining(tester, saveWith(onCooldown: true));
      final penalty = container
          .read(miniGamesProvider)
          .firstWhere((g) => g.kind == MiniGameKind.penalty);
      expect(penalty.ready, isFalse);
      expect(penalty.waitMs, greaterThan(0));
    });
  });

  /// Tap the goalmouth at a point in scene percentages — the goal IS the
  /// target, so a test aims the way a player does rather than pressing a button
  /// named after a corner.
  /// One swipe at the goal.
  ///
  /// [across] and [lift] are where the thumb FINISHES, as a fraction of the
  /// view — which is the aim. [hook] bends the drag, which is the curl. The
  /// gesture has to be a real drag: a tap is deliberately not a shot, because a
  /// stray touch must not spend one of five attempts.
  Future<void> swipe(
    WidgetTester tester, {
    double across = 0.5,
    double lift = 0.5,
    double hook = 0,
  }) async {
    final view = find.byKey(const ValueKey('penalty-swipe'));
    final rect = tester.getRect(view);
    final from = Offset(
      rect.left + rect.width * 0.5,
      rect.top + rect.height * 0.92,
    );
    final to = Offset(
      rect.left + rect.width * across,
      rect.top + rect.height * lift,
    );
    final gesture = await tester.startGesture(from);
    // Three moves, so the middle one is sampled as the hook.
    final mid = Offset.lerp(from, to, 0.5)!;
    await gesture.moveTo(Offset.lerp(from, to, 0.2)!);
    await gesture.moveTo(mid.translate(rect.width * hook, 0));
    await gesture.moveTo(to);
    await gesture.up();
    await tester.pump();
    // The flight and the hold that follows it are real time on a ticker: a
    // floated penalty is over a second in the air and the hold is nearly two, so
    // the wait has to cover both or the next swipe is refused.
    for (var i = 0; i < 260; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  group('Penalty Training', () {
    testWidgets('opens from the list and claims the mini-game gate', (
      tester,
    ) async {
      final container = await pumpTraining(tester, saveWith());
      await tester.tap(find.byKey(const ValueKey('training-penalty')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(find.byKey(const ValueKey('penalty-screen')), findsOneWidget);
      // A modal over a mini-game would never be dismissed.
      expect(container.read(tickGatesProvider).miniGameOpen, isTrue);
    });

    testWidgets('runs its five shots and pays once at the end', (tester) async {
      final container = await pumpTraining(tester, saveWith());
      await tester.tap(find.byKey(const ValueKey('training-penalty')));
      await tester.pumpAndSettle();

      final coinsBefore = container.read(coinsProvider);
      for (var i = 0; i < Penalty.attempts; i++) {
        await swipe(tester, across: 0.3 + 0.1 * i, lift: 0.42);
      }
      await settleSave(tester);

      final state = tester.state<PenaltyScreenState>(
        find.byType(PenaltyScreen),
      );
      expect(state.finished, isTrue);
      expect(find.byKey(const ValueKey('penalty-reward')), findsOneWidget);
      // Scoring nothing is possible, so the payout is >= rather than >.
      expect(container.read(coinsProvider), greaterThanOrEqualTo(coinsBefore));
      expect(state.scored, inInclusiveRange(0, Penalty.attempts));
    });

    testWidgets('a swipe past the post goes WIDE, and says which side', (
      tester,
    ) async {
      // The whole reason the goal is simulated rather than picked from a menu:
      // with four buttons there is no way to miss, so `penalty.wide_left` was
      // shipped copy nothing could ever reach.
      await pumpTraining(tester, saveWith());
      await tester.tap(find.byKey(const ValueKey('training-penalty')));
      await tester.pumpAndSettle();

      await swipe(tester, across: -0.15, lift: 0.45);
      final state = tester.state<PenaltyScreenState>(
        find.byType(PenaltyScreen),
      );
      expect(state.lastResult?.result, PenaltyResult.wide);
      expect(state.scored, 0);
      expect(find.text(t('penalty.wide_left')), findsOneWidget);
      await settleSave(tester);
    });

    testWidgets('and over the top goes OVER', (tester) async {
      await pumpTraining(tester, saveWith());
      await tester.tap(find.byKey(const ValueKey('training-penalty')));
      await tester.pumpAndSettle();

      await swipe(tester, across: 0.5, lift: -0.25);
      final state = tester.state<PenaltyScreenState>(
        find.byType(PenaltyScreen),
      );
      expect(state.lastResult?.result, PenaltyResult.over);
      expect(find.text(t('penalty.over_the_bar')), findsOneWidget);
      await settleSave(tester);
    });

    testWidgets('a TAP is not a shot, so a stray touch costs nothing', (
      tester,
    ) async {
      // Five attempts is the whole game.
      await pumpTraining(tester, saveWith());
      await tester.tap(find.byKey(const ValueKey('training-penalty')));
      await tester.pumpAndSettle();

      final view = find.byKey(const ValueKey('penalty-swipe'));
      final rect = tester.getRect(view);
      await tester.tapAt(rect.center);
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state<PenaltyScreenState>(
        find.byType(PenaltyScreen),
      );
      expect(state.lastResult, isNull);
      expect(state.finished, isFalse);
      await settleSave(tester);
    });

    testWidgets('SOMEBODY TAKES IT — the run-up holds the ball on the spot', (
      tester,
    ) async {
      // The scene had nobody in it: the ball left the spot on its own. The kick
      // exists from the moment the swipe ends — it is decided, and a second
      // swipe is already refused — but the BALL waits for him.
      await pumpTraining(tester, saveWith());
      await tester.tap(find.byKey(const ValueKey('training-penalty')));
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.byKey(const ValueKey('penalty-swipe')));
      final gesture = await tester.startGesture(
        Offset(rect.center.dx, rect.bottom - 8),
      );
      await gesture.moveTo(Offset(rect.center.dx, rect.center.dy));
      await gesture.moveTo(Offset(rect.center.dx, rect.top + 12));
      await gesture.up();
      await tester.pump();

      final view = tester.state<PenaltyViewState>(find.byType(PenaltyView));
      expect(view.kick, isNotNull, reason: 'the shot was not decided');
      expect(view.runningUp, isTrue);
      final atSpot = view.kick!.position.y;

      // FRAME BY FRAME. A single long pump is one frame carrying the whole
      // duration, and the loop clamps a frame's dt at 50ms so a slow device
      // cannot teleport the ball — so a 250ms pump advances the run-up by 50.
      Future<void> frames(int n) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      // Half way through the run-up the ball has not moved.
      await frames(15);
      expect(view.runningUp, isTrue);
      expect(view.kick!.position.y, atSpot);
      expect(view.kick!.elapsed, 0, reason: 'the physics ran under him');

      // Past the plant, and it is on its way.
      await frames(30);
      expect(view.runningUp, isFalse);
      expect(view.kick!.position.y, greaterThan(atSpot));

      for (var i = 0; i < 260; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await settleSave(tester);
    });

    testWidgets('and a second swipe during the flight does not spend one', (
      tester,
    ) async {
      await pumpTraining(tester, saveWith());
      await tester.tap(find.byKey(const ValueKey('training-penalty')));
      await tester.pumpAndSettle();

      final view = find.byKey(const ValueKey('penalty-swipe'));
      final rect = tester.getRect(view);
      Future<void> quickSwipe() async {
        final g = await tester.startGesture(
          Offset(rect.center.dx, rect.bottom - 8),
        );
        await g.moveTo(Offset(rect.center.dx, rect.top + rect.height * 0.45));
        await g.up();
      }

      await quickSwipe();
      await tester.pump(const Duration(milliseconds: 50));
      await quickSwipe();
      for (var i = 0; i < 260; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final state = tester.state<PenaltyScreenState>(
        find.byType(PenaltyScreen),
      );
      expect(state.lastResult, isNotNull);
      expect(
        tester.state<PenaltyScreenState>(find.byType(PenaltyScreen)).finished,
        isFalse,
      );
      await settleSave(tester);
    });

    testWidgets('the cooldown starts on entry, not on finishing', (
      tester,
    ) async {
      // Walking away mid-round must not farm the reward timer.
      final container = await pumpTraining(tester, saveWith());
      expect(
        container
            .read(miniGamesProvider)
            .firstWhere((g) => g.kind == MiniGameKind.penalty)
            .ready,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('training-penalty')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(
        container
            .read(miniGamesProvider)
            .firstWhere((g) => g.kind == MiniGameKind.penalty)
            .ready,
        isFalse,
      );
    });

    testWidgets('and hands the gate back on the way out', (tester) async {
      final container = await pumpTraining(tester, saveWith());
      await tester.tap(find.byKey(const ValueKey('training-penalty')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(container.read(tickGatesProvider).miniGameOpen, isFalse);
    });
  });
}
