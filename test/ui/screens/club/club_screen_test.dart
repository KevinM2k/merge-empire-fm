/// The Club tab.
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
import 'package:merge_empire_fc/ui/screens/club/club_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

const String _key = AssetCategory.training;

Future<ProviderContainer> pumpClub(
  WidgetTester tester, {
  int coins = 0,
  int players = 1,
}) async {
  final state = createDefaultState();
  (state['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  final cells = (state['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
  for (var i = 0; i < players; i++) {
    cells[i] = <String, dynamic>{'definitionId': 'p', 'instanceId': 'c$i'};
  }

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
          home: const Scaffold(body: ClubScreen()),
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

  testWidgets('lists every shipped facility', (tester) async {
    await pumpClub(tester);
    for (final key in AssetCategory.all) {
      expect(
        find.byKey(ValueKey('club-asset-$key'), skipOffstage: false),
        findsOneWidget,
        reason: key,
      );
    }
  });

  testWidgets('counts what is owned', (tester) async {
    final container = await pumpClub(tester, coins: 100000);
    expect(container.read(ownedAssetCountProvider), 0);

    await tester.tap(find.byKey(const ValueKey('club-action-$_key')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(container.read(ownedAssetCountProvider), 1);
  });

  testWidgets('building costs the build price and opens at tier one', (
    tester,
  ) async {
    final container = await pumpClub(tester, coins: 100000);
    final before = container.read(coinsProvider);

    await tester.tap(find.byKey(const ValueKey('club-action-$_key')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(container.read(coinsProvider), before - buildCost);
    final tile = container
        .read(assetTilesProvider)
        .firstWhere((t) => t.key == _key);
    expect(tile.owned, isTrue);
    expect(tile.tier, 1);
  });

  testWidgets('investing banks coins against the tier', (tester) async {
    final container = await pumpClub(tester, coins: 10000000);
    await tester.tap(find.byKey(const ValueKey('club-action-$_key')));
    await tester.pumpAndSettle();
    await settleSave(tester);
    expect(container.read(assetTilesProvider).firstWhere((t) => t.key == _key).progress, 0);

    final before = container.read(coinsProvider);
    await tester.tap(find.byKey(const ValueKey('club-action-$_key')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(container.read(coinsProvider), lessThan(before));
    expect(
      container.read(assetTilesProvider).firstWhere((t) => t.key == _key).progress,
      greaterThan(0),
    );
  });

  testWidgets('a bar only appears once something is built', (tester) async {
    final container = await pumpClub(tester, coins: 100000);
    expect(find.byKey(const ValueKey('club-progress-$_key')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('club-action-$_key')));
    await tester.pumpAndSettle();
    await settleSave(tester);
    expect(container.read(assetTilesProvider).first.owned, isTrue);
    expect(
      find.byKey(const ValueKey('club-progress-$_key'), skipOffstage: false),
      findsOneWidget,
    );
  });

  group('what the engine refuses', () {
    testWidgets('a skint club cannot build, and is told why', (tester) async {
      await pumpClub(tester, coins: 0);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('club-action-$_key')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text(t('toast.not_enough_coins')), findsWidgets);
    });

    testWidgets('a club with no players cannot build, and is told why', (
      tester,
    ) async {
      // The first facility needs somebody to put in it.
      await pumpClub(tester, coins: 100000, players: 0);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('club-action-$_key')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text(t('club.build_needs_player')), findsWidgets);
    });

    testWidgets('a maxed facility offers nothing more', (tester) async {
      final container = await pumpClub(tester, coins: 100000000);
      container.read(gameProvider).update((s) {
        (s['clubAssets'] as Map<String, dynamic>)[_key] = <String, dynamic>{
          'owned': true,
          'tier': maxAssetTier,
          'invested': 0,
          'tapCount': 0,
        };
      });
      await tester.pumpAndSettle();
      await settleSave(tester);

      final tile = container
          .read(assetTilesProvider)
          .firstWhere((t) => t.key == _key);
      expect(tile.maxed, isTrue);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('club-action-$_key')),
            )
            .onPressed,
        isNull,
      );
    });
  });
}
