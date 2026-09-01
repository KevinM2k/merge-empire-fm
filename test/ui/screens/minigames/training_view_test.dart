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
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart';
import 'package:merge_empire_fc/ui/screens/minigames/training_view.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/time.dart';

Future<void> pumpTraining(
  WidgetTester tester, {
  void Function(Map<String, dynamic> state)? mutate,

  /// The theme, spelled out rather than taken off the save: the money and the
  /// arrow are both theme-aware and the two halves are what is under test.
  bool? light,

  /// The container, for a test that has to read the SAVE back after a tap.
  void Function(ProviderContainer container)? onContainer,
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
  onContainer?.call(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: light == null
              ? ref.watch(appThemeProvider)
              : buildAppTheme(kitId: '#4caf50', light: light),
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

  /// **ONE SKIP, FOR THE WHOLE SHEET.**
  ///
  /// It was a per-drill button in each resting row, so clearing the penalty
  /// game's wait left the other six on the clock and the day only has three
  /// skips in it. `skipKinds` has been documented as "every kind one skip
  /// clears" since M1 with no caller, alongside `resetMiniGameCooldown`,
  /// `recordSkipAd`, and `minigame.skip_all_ad` / `minigame.skip_all_left`,
  /// which were shipped in ten catalogues and printed nowhere.
  group('THE SKIP IS ABOVE ALL THE DRILLS, and it clears all of them', () {
    testWidgets('it appears once a drill is waiting, not once per drill', (
      tester,
    ) async {
      await pumpTraining(tester, mutate: (s) {
        trainingTier(s, 6);
        // Two of the seven just played, so two are resting.
        startMiniGame(s, MiniGameKind.penalty);
        startMiniGame(s, MiniGameKind.pairs);
      });
      expect(find.byKey(const ValueKey('training-skip-all')), findsOneWidget);
      // And nothing in the rows themselves.
      for (final kind in MiniGameKind.all) {
        expect(find.byKey(ValueKey('training-skip-$kind')), findsNothing);
      }
    });

    testWidgets('and TAPPING IT takes every drill off the clock', (
      tester,
    ) async {
      late ProviderContainer container;
      await pumpTraining(
        tester,
        mutate: (s) {
          trainingTier(s, 6);
          for (final kind in MiniGameKind.all) {
            startMiniGame(s, kind);
          }
        },
        onContainer: (c) => container = c,
      );
      final state = container.read(gameProvider).state!;
      expect(
        MiniGameKind.all.every((k) => !miniGameReady(state, k)),
        isTrue,
        reason: 'nothing was resting to begin with',
      );

      await tester.tap(find.byKey(const ValueKey('training-skip-all')));
      await tester.pumpAndSettle();

      for (final kind in MiniGameKind.all) {
        expect(
          miniGameReady(state, kind),
          isTrue,
          reason: '$kind is still cooling down',
        );
      }
      // One of the day's three, spent.
      expect(skipAdsLeftToday(state), Minigame.skipCapPerDay - 1);
      // And with nothing left to skip it goes.
      expect(find.byKey(const ValueKey('training-skip-all')), findsNothing);
    });

    testWidgets('a day with no skips left says so and is dead', (tester) async {
      await pumpTraining(tester, mutate: (s) {
        trainingTier(s, 6);
        startMiniGame(s, MiniGameKind.penalty);
        for (var i = 0; i < Minigame.skipCapPerDay; i++) {
          recordSkipAd(s);
        }
      });
      final button = tester.widget<StoreButton>(
        find.descendant(
          of: find.byKey(const ValueKey('training-skip-all')),
          matching: find.byType(StoreButton),
        ),
      );
      expect(button.onTap, isNull);
      expect(button.label, t('minigame.skip_all_capped'));
    });

    testWidgets('and a sheet with nothing waiting does not offer one', (
      tester,
    ) async {
      // Every drill unlocked and none of them played: an offer to clear
      // cooldowns with no cooldown to clear.
      await pumpTraining(tester, mutate: (s) => trainingTier(s, 6));
      expect(find.byKey(const ValueKey('training-skip-all')), findsNothing);
    });

    testWidgets('a LOCKED drill is not something to skip either', (
      tester,
    ) async {
      await pumpTraining(tester, mutate: (s) => trainingTier(s, 0));
      expect(find.byKey(const ValueKey('training-skip-all')), findsNothing);
    });
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

  /// **MONEY IS GOLD AND THE ARROW IS WHITE.** The coin figure and the play
  /// arrow both took the drill's own hue — the kit's accent walked up to 252°
  /// round the wheel — so the seven rows quoted their money in seven colours
  /// and the ones landing near the card's own surface could not be read.
  /// Reported from an Android handset in dark mode.
  group('the money and the arrow', () {
    Iterable<Color?> coinInks(WidgetTester tester) => [
      for (final icon in tester.widgetList<GameIcon>(
        find.byWidgetPredicate((w) => w is GameIcon && w.name == 'coin'),
      ))
        icon.color,
    ];

    Iterable<Color?> arrowInks(WidgetTester tester) => [
      for (final icon in tester.widgetList<Icon>(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.play_arrow),
      ))
        icon.color,
    ];

    /// **AND THE FIGURE IS IN A BADGE NOW, in both themes.**
    ///
    /// It was `coinFigureInk` — bright gold in the dark theme and the deep
    /// bronze `gameGoldLight` on a light page, which is right for gold ON
    /// WHITE and was reported from the couch as horrible on this list. Every
    /// other figure in the game fills the chip in the wallet's colour and
    /// prints in a tint of it; so does this one, so the ink no longer moves
    /// with the theme at all.
    testWidgets('every drill quotes its ceiling in the coin badge', (
      tester,
    ) async {
      for (final light in [false, true]) {
        await pumpTraining(
          tester,
          light: light,
          mutate: (s) => trainingTier(s, 6),
        );
        final inks = coinInks(tester);
        expect(inks, isNotEmpty, reason: 'no drill said what it pays');
        expect(
          inks,
          everyElement(hudBadgeInk(hudBadgeColour(hudCoinInk))),
          reason: 'light=$light',
        );
        // The two shades the bare figure used to take, neither of which is a
        // colour on a filled chip.
        expect(inks, isNot(contains(gameGold)));
        expect(inks, isNot(contains(gameGoldLight)));
      }
    });


    testWidgets('and the little arrows are white in dark mode', (tester) async {
      await pumpTraining(
        tester,
        light: false,
        mutate: (s) => trainingTier(s, 6),
      );
      final inks = arrowInks(tester);
      expect(inks, isNotEmpty);
      expect(inks, everyElement(Colors.white));
    });

    testWidgets('and keep the drill tint in light mode, which is what tells '
        'the seven rows apart', (tester) async {
      await pumpTraining(
        tester,
        light: true,
        mutate: (s) => trainingTier(s, 6),
      );
      expect(arrowInks(tester), isNot(contains(Colors.white)));
    });
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
