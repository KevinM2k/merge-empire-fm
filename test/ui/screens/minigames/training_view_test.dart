/// The Drills list.
///
/// The two things checked here are both cases where a control looked broken and
/// was not: a drill the Training Ground has not reached, which said nothing about
/// which tier would reach it, and a drill that is only waiting on a clock, which
/// offered no way out of the wait even though the engine has had one since M1.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/minigames/training_view.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/time.dart';

Future<void> pumpTraining(
  WidgetTester tester, {
  void Function(Map<String, dynamic> state)? mutate,
}) async {
  final state = createDefaultState();
  mutate?.call(state);
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
}

void trainingTier(Map<String, dynamic> state, int tier) =>
    (state['clubAssets'] as Map<String, dynamic>)[AssetCategory.training] = {
      'owned': true,
      'tier': tier,
      'invested': 0,
      'tapCount': 0,
    };

void main() {
  test('the ladder is data, and it matches what unlocks', () {
    // Two callers need it — the unlocked list and the locked row's copy — and a
    // second stack of ifs would have drifted from the first.
    for (var tier = 0; tier <= 6; tier++) {
      final state = createDefaultState();
      trainingTier(state, tier);
      final unlocked = getUnlockedMinigames(
        state['clubAssets'] as Map<String, dynamic>,
      );
      for (final entry in minigameUnlockTier.entries) {
        expect(
          unlocked.contains(entry.key),
          tier >= entry.value,
          reason: '${entry.key} at training tier $tier',
        );
      }
    }
  });

  testWidgets('a locked drill NAMES the tier that unlocks it', (tester) async {
    // It asked for `club.minigame_unlocked` with no parameters, so the row
    // rendered the literal `{name} unlocked` — and left "not unlocked yet" and
    // "no screen for it yet" both saying nothing useful.
    await pumpTraining(tester, mutate: (s) => trainingTier(s, 1));
    final expected =
        '${t('asset.${AssetCategory.training}.name')} · '
        '${t('club.tier_n', {'n': minigameUnlockTier[MiniGameKind.bootRoom]})}';
    expect(find.text(expected), findsOneWidget);
    expect(find.textContaining('{name}'), findsNothing);
  });

  testWidgets('a drill that is only WAITING offers the skip', (tester) async {
    // The engine has had `resetMiniGameCooldown`, `skipAdsLeftToday` and the
    // daily cap since M1 with no caller at all.
    await pumpTraining(tester, mutate: (s) {
      trainingTier(s, 6);
      // Just played, so the penalty drill is resting.
      startMiniGame(s, MiniGameKind.penalty);
    });
    expect(
      find.byKey(const ValueKey('training-skip-${MiniGameKind.penalty}')),
      findsOneWidget,
    );
    // Dead until AdMob lands, and shown rather than hidden — see the note on the
    // row.
    expect(
      tester
          .widget<StoreButton>(
            find.byKey(const ValueKey('training-skip-${MiniGameKind.penalty}')),
          )
          .onTap,
      isNull,
    );
  });

  testWidgets('and a LOCKED one does not — there is nothing to skip', (
    tester,
  ) async {
    await pumpTraining(tester, mutate: (s) => trainingTier(s, 0));
    expect(
      find.byKey(const ValueKey('training-skip-${MiniGameKind.bootRoom}')),
      findsNothing,
    );
  });

  testWidgets('a ready drill shows neither a reason nor a skip', (
    tester,
  ) async {
    await pumpTraining(tester, mutate: (s) => trainingTier(s, 6));
    expect(
      find.byKey(const ValueKey('training-skip-${MiniGameKind.penalty}')),
      findsNothing,
    );
    expect(find.byIcon(Icons.play_arrow), findsWidgets);
  });

  testWidgets('a resting drill says how long is left', (tester) async {
    await pumpTraining(tester, mutate: (s) {
      trainingTier(s, 6);
      startMiniGame(s, MiniGameKind.penalty);
    });
    expect(
      find.textContaining(t('play.cooldown', {'time': ''}).split('{')[0].trim()),
      findsWidgets,
      reason: 'no clock on a resting drill',
    );
    expect(formatDuration(0), isNotEmpty);
  });
}
