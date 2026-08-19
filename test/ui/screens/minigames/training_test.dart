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
import 'package:merge_empire_fc/ui/screens/minigames/penalty_scene.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_screen.dart';
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

    testWidgets('a game with no screen yet says so rather than offering', (
      tester,
    ) async {
      // Listing one that leads nowhere is the bug this whole tab replaced.
      final container = await pumpTraining(tester, saveWith(trainingTier: 6));
      final unbuilt = container
          .read(miniGamesProvider)
          .where((g) => g.unlocked && !g.playable);
      expect(unbuilt, isNotEmpty);
      expect(find.text(t('settings.comingSoon')), findsWidgets);
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
  Future<void> shootAt(WidgetTester tester, double x, double y) async {
    final scene = find.byKey(const ValueKey('penalty-goal'));
    final rect = tester.getRect(scene);
    await tester.tapAt(
      Offset(
        rect.left + rect.width * x / 100,
        rect.top + rect.height * y / 100,
      ),
    );
    await tester.pumpAndSettle();
    // The strike plays out on a timer, and the next shot is refused until it
    // has. `pumpAndSettle` only chases frames, so the wait has to be explicit.
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();
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
        await shootAt(tester, 25, 15);
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

    testWidgets('a shot outside the frame goes wide and never asks the keeper', (
      tester,
    ) async {
      // The whole reason the goal is the target rather than four buttons: with
      // buttons there is no way to miss, so `penalty.wide_left` was shipped
      // copy nothing could ever reach.
      await pumpTraining(tester, saveWith());
      await tester.tap(find.byKey(const ValueKey('training-penalty')));
      await tester.pumpAndSettle();

      await shootAt(tester, 2, 25);
      final state = tester.state<PenaltyScreenState>(
        find.byType(PenaltyScreen),
      );
      expect(state.lastResult, ShotResult.wideLeft);
      expect(state.scored, 0);
      expect(find.text(t('penalty.wide_left')), findsOneWidget);
      await settleSave(tester);
    });

    testWidgets('clipping a post is its own outcome, not a save', (
      tester,
    ) async {
      await pumpTraining(tester, saveWith());
      await tester.tap(find.byKey(const ValueKey('training-penalty')));
      await tester.pumpAndSettle();

      // Just inside the left post, within the woodwork margin.
      await shootAt(tester, goalFrame.left + 1, 25);
      final state = tester.state<PenaltyScreenState>(
        find.byType(PenaltyScreen),
      );
      expect(state.lastResult, ShotResult.post);
      expect(state.scored, 0);
      await settleSave(tester);
    });

    testWidgets('a second tap during the strike does not spend an attempt', (
      tester,
    ) async {
      // Five attempts is the whole game; a double tap must not cost two.
      await pumpTraining(tester, saveWith());
      await tester.tap(find.byKey(const ValueKey('training-penalty')));
      await tester.pumpAndSettle();

      final scene = find.byKey(const ValueKey('penalty-goal'));
      final rect = tester.getRect(scene);
      final at = Offset(
        rect.left + rect.width * 0.25,
        rect.top + rect.height * 0.15,
      );
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(at);
      await tester.pumpAndSettle();

      final state = tester.state<PenaltyScreenState>(
        find.byType(PenaltyScreen),
      );
      expect(state.finished, isFalse);
      expect(state.scored, inInclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 950));
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
