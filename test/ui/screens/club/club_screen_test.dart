/// The Club tab.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/feature_unlock.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/club/asset_tier_copy.dart';
import 'package:merge_empire_fc/ui/screens/club/club_screen.dart';
import 'package:merge_empire_fc/ui/screens/club/club_stats_panel.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/svg_canvas.dart';
import 'package:merge_empire_fc/util/format.dart';

const String _key = AssetCategory.training;

Future<ProviderContainer> pumpClub(
  WidgetTester tester, {
  int coins = 0,
  int players = 1,
  void Function(Map<String, dynamic> state)? mutate,
}) async {
  final state = createDefaultState();
  (state['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  mutate?.call(state);
  final cells =
      (state['grid'] as Map<String, dynamic>)['cells'] as List<dynamic>;
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

  testWidgets('AN ASSET CARD LIFTS OFF THE PAGE, face and all', (tester) async {
    // Fourth report of these blending in. Every pass before this added contrast
    // around the outside of a FLAT `surface` fill, and a flat fill is the thing
    // that reads as page — on humbug and turf the card is literally one of the
    // two band colours. The app's own answer to this exact complaint is the
    // shop's `.look-tile`: `surface2 → surface` raked down and right with a
    // shadow under it.
    await pumpClub(tester);
    final box = tester
        .widget<Container>(
          find
              .descendant(
                of: find.byKey(const ValueKey('club-asset-$_key')),
                matching: find.byType(Container),
              )
              .first,
        )
        .decoration!
        as BoxDecoration;

    expect(box.gradient, isNotNull, reason: 'a flat fill IS the page');
    expect(box.color, isNull);
    expect(box.boxShadow, isNotNull);
    expect(box.boxShadow!.length, greaterThan(1));
    final colors = (box.gradient! as LinearGradient).colors;
    // The lit corner and the shaded one are different values, or it is a flat
    // fill written the long way.
    expect(colors.first, isNot(colors.last));
  });

  testWidgets('and an owned one is edged in its own tier metal', (tester) async {
    // "A slightly different colour so they stand out" — the tier is already on
    // the badge and the glyph, so the card takes it too rather than seven grey
    // cards being told apart only by their photographs.
    final container = await pumpClub(tester, coins: 100000);
    await tester.tap(find.byKey(const ValueKey('club-action-$_key')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    final box = tester
        .widget<Container>(
          find
              .descendant(
                of: find.byKey(const ValueKey('club-asset-$_key')),
                matching: find.byType(Container),
              )
              .first,
        )
        .decoration!
        as BoxDecoration;
    final tier = container.read(gameProvider).state!['clubAssets']
        as Map<String, dynamic>;
    final ink = assetTierColour(
      ((tier[_key] as Map<String, dynamic>)['tier'] as num).toInt(),
    );
    expect(
      (box.border! as Border).top.color.toARGB32() & 0x00FFFFFF,
      ink.toARGB32() & 0x00FFFFFF,
    );
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
    expect(
      container
          .read(assetTilesProvider)
          .firstWhere((t) => t.key == _key)
          .progress,
      0,
    );

    final before = container.read(coinsProvider);
    await tester.tap(find.byKey(const ValueKey('club-action-$_key')));
    await tester.pumpAndSettle();
    await settleSave(tester);

    expect(container.read(coinsProvider), lessThan(before));
    expect(
      container
          .read(assetTilesProvider)
          .firstWhere((t) => t.key == _key)
          .progress,
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
            .widget<StoreButton>(
              find.byKey(const ValueKey('club-action-$_key')),
            )
            .onTap,
        isNull,
      );
      // The BUTTON says how far short, rather than only going grey: "you
      // cannot" and "you need this much more" are different sentences.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('club-action-$_key')),
          matching: find.textContaining(formatCoins(buildCost)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a club with no players cannot build, and is told why', (
      tester,
    ) async {
      // The first facility needs somebody to put in it.
      await pumpClub(tester, coins: 100000, players: 0);
      expect(
        tester
            .widget<StoreButton>(
              find.byKey(const ValueKey('club-action-$_key')),
            )
            .onTap,
        isNull,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('club-action-$_key')),
          matching: find.text(t('club.sign_player_first')),
        ),
        findsOneWidget,
      );
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
            .widget<StoreButton>(
              find.byKey(const ValueKey('club-action-$_key')),
            )
            .onTap,
        isNull,
      );
    });
  });

  group('the artwork', () {
    testWidgets('every tile draws its real art', (tester) async {
      // It was a tier badge until clubArt landed.
      await pumpClub(tester, coins: 100000);
      for (final key in AssetCategory.all) {
        expect(
          find.byKey(ValueKey('club-art-$key'), skipOffstage: false),
          findsOneWidget,
          reason: key,
        );
      }
    });

    testWidgets('an unbuilt facility shows what it WOULD look like, dimmed', (
      tester,
    ) async {
      // A preview is a better prompt than an empty square.
      await pumpClub(tester, coins: 100000);
      ArtImage art() => tester.widget<ArtImage>(
        find.byKey(const ValueKey('club-art-$_key'), skipOffstage: false),
      );
      expect(art().dimmed, isTrue);

      await tester.tap(find.byKey(const ValueKey('club-action-$_key')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(art().dimmed, isFalse);
    });

    testWidgets('the stadium hero hangs over the screen', (tester) async {
      // An unbuilt Stadium still shows tier one: the club plays somewhere
      // whether or not it has invested, and an empty band reads as a bug.
      await pumpClub(tester, coins: 100000);
      expect(
        tester
            .widget<ArtImage>(find.byKey(const ValueKey('club-stadium-hero-1')))
            .path,
        stadiumBackgroundPath(1),
      );
    });

    testWidgets('a tile asks for the generated art, not the drawing', (
      tester,
    ) async {
      // PNG-first is the whole point: the port had been shipping the JS's
      // `onerror` fallback as though it were the artwork.
      await pumpClub(tester, coins: 100000);
      final art = tester.widget<ArtImage>(
        find.byKey(const ValueKey('club-art-$_key'), skipOffstage: false),
      );
      expect(art.path, clubAssetImagePath(_key, 1));
      // And the drawing is still there behind it, for a facility whose art has
      // not been generated yet.
      expect(art.fallback, isA<SvgArt>());
    });
  });

  group('building says so', () {
    testWidgets('a first build raises the UNLOCKED splash', (tester) async {
      // The port took the coins, ticked the bar and said nothing — the one moment
      // on this screen a player pays for looked like a number changing.
      await pumpClub(tester, coins: 100000);
      await tester.tap(find.byKey(const ValueKey('club-action-$_key')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const ValueKey('feature-unlock')), findsOneWidget);
      expect(find.text(t('feature.unlocked')), findsNothing);
      // The eyebrow carries a glyph with it, so the word is matched loosely.
      expect(find.textContaining(t('feature.unlocked')), findsOneWidget);
      expect(find.text(t('asset.$_key.name')), findsWidgets);

      // It takes itself away.
      await tester.pump(featureUnlockHold);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feature-unlock')), findsNothing);
      await settleSave(tester);
    });

    testWidgets('BUT NOT ON EVERY TAP — only when the bar fills', (
      tester,
    ) async {
      // Filling tier one takes TEN taps and tier seven takes forty, and the
      // splash went up on every one of them: a full-screen celebration standing
      // between the player and the button they are trying to press again.
      await pumpClub(tester, coins: 10000000);
      final action = find.byKey(const ValueKey('club-action-$_key'));
      await tester.tap(action);
      await tester.pump();
      await tester.pump(featureUnlockHold);
      await tester.pumpAndSettle();

      // One tap into tier one, which needs ten of them. Nothing to celebrate.
      await tester.tap(action);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const ValueKey('feature-unlock')),
        findsNothing,
        reason: 'a single tap of a ten-tap tier threw a party',
      );
      await settleSave(tester);
    });

    testWidgets('and the tap that FILLS it says TIER UP', (tester) async {
      // The same card with a different eyebrow, deliberately: they are the same
      // kind of event, and a different shape would make the smaller one read as
      // a lesser thing rather than the next step of the same thing.
      await pumpClub(tester, coins: 10000000);
      final action = find.byKey(const ValueKey('club-action-$_key'));
      await tester.tap(action);
      await tester.pump();
      await tester.pump(featureUnlockHold);
      await tester.pumpAndSettle();

      // Tier one takes `tapsForTier(1)` taps. The last one is the event.
      for (var i = 0; i < tapsForTier(1); i++) {
        await tester.tap(action);
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining(t('feature.tier_up')), findsOneWidget);

      await tester.pump(featureUnlockHold);
      await tester.pumpAndSettle();
      await settleSave(tester);
    });

    testWidgets('and a tap dismisses it early', (tester) async {
      await pumpClub(tester, coins: 100000);
      await tester.tap(find.byKey(const ValueKey('club-action-$_key')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('feature-unlock')), findsOneWidget);

      // Nothing on the card is a decision, so anywhere will do.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feature-unlock')), findsNothing);
      await settleSave(tester);
    });
  });

  group('what a card says', () {
    /// Own the facility at [tier] so the card has something to report.
    Future<ProviderContainer> pumpOwned(
      WidgetTester tester, {
      int tier = 1,
      int coins = 100000000,
    }) async {
      final container = await pumpClub(tester, coins: coins);
      container.read(gameProvider).update((s) {
        final assets = s['clubAssets'] as Map<String, dynamic>;
        assets[_key] = <String, dynamic>{
          'owned': true,
          'tier': tier,
          'invested': 0,
          'tapCount': 0,
        };
      });
      await tester.pumpAndSettle();
      // The mutation arms the debounced save; a test that walks away from it
      // ends with a timer pending and the binding rightly complains.
      await settleSave(tester);
      return container;
    }

    testWidgets('WHAT IT GIVES, which the card had never said', (tester) async {
      // `club_asset_tiers.dart` is a ported, tested engine that computes exactly
      // this and had no caller at all: the card showed a name, a hint and a
      // price, so a player investing could not know what they were buying.
      await pumpOwned(tester, tier: 3);
      expect(assetPerkLine(_key, 3), isNot('—'));
      expect(find.text(assetPerkLine(_key, 3)), findsOneWidget);
    });

    testWidgets('and only what the NEXT tier changes', (tester) async {
      await pumpOwned(tester, tier: 3);
      final next = assetNextLine(_key, 3);
      expect(next, isNotNull);
      expect(find.byKey(const ValueKey('club-next-$_key')), findsOneWidget);
      expect(find.text(next!), findsOneWidget);
      expect(
        next,
        isNot(assetPerkLine(_key, 3)),
        reason: 'a next line that repeats the current one reads as broken',
      );
    });

    testWidgets('AND IT MOVES ON EVERY TAP, not only on the tier-up', (
      tester,
    ) async {
      // The engine has paid the continuous effects per tap since
      // `fractionalAssetTier` went in — twenty clicks for ten per cent is half a
      // per cent a click — but the card read the whole rung, so it said "-5%
      // cooldown" for the entire climb to -10% and only jumped at the top.
      // Reported from the couch: it should move, even if it moves to -5.01%.
      final container = await pumpOwned(tester, tier: 1);
      final before = assetPerkLine(_key, 1);
      expect(find.text(before), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('club-action-$_key')));
      await tester.pumpAndSettle();
      await settleSave(tester);

      final live = fractionalAssetTier(
        container.read(gameProvider).state?['clubAssets']
            as Map<String, dynamic>?,
        _key,
      );
      expect(live, greaterThan(1));
      expect(live, lessThan(2), reason: 'one tap is not a whole tier');
      expect(
        find.text(before),
        findsNothing,
        reason: 'the card still claims the rung it started on',
      );
      expect(find.text(assetPerkLine(_key, live)), findsOneWidget);
    });

    testWidgets('and the bar FILLS to its new mark', (tester) async {
      // It moved a whole step between frames, so the one control whose job is
      // to show progress showed only the result of it.
      await pumpOwned(tester, tier: 1);
      double bar() => tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('club-progress-$_key')),
          )
          .value!;
      expect(bar(), 0);

      await tester.tap(find.byKey(const ValueKey('club-action-$_key')));
      // One frame past the tap: the value is on its way, not there.
      await tester.pump();
      await tester.pump(assetBarFill ~/ 3);
      final midway = bar();
      await tester.pumpAndSettle();
      final settled = bar();
      await settleSave(tester);

      expect(settled, greaterThan(0));
      expect(
        midway,
        lessThan(settled),
        reason: 'the bar jumped straight to its new value',
      );
    });

    testWidgets('the tier it is at, on the art', (tester) async {
      await pumpOwned(tester, tier: 4);
      expect(
        find.byKey(const ValueKey('club-tier-badge-$_key')),
        findsOneWidget,
      );
      expect(find.text(t('club.tier_n', {'n': 4})), findsWidgets);
    });

    testWidgets('and a LOCK while it is unbuilt', (tester) async {
      await pumpClub(tester, coins: 100000);
      expect(find.byKey(const ValueKey('club-locked-$_key')), findsOneWidget);
      expect(find.byKey(const ValueKey('club-tier-badge-$_key')), findsNothing);
      expect(
        find.byKey(const ValueKey('club-next-$_key')),
        findsNothing,
        reason: 'nothing to step up from yet',
      );
    });

    testWidgets('the top of the ladder says so rather than going blank', (
      tester,
    ) async {
      await pumpOwned(tester, tier: maxAssetTier);
      expect(
        find.textContaining(t('club.maxed')),
        findsWidgets,
        reason: 'a blank row punched a hole between the bar and the button',
      );
    });
  });

  group('the upgrade path', () {
    testWidgets('opens from the card, and lands on the tier the club is on', (
      tester,
    ) async {
      final container = await pumpClub(tester, coins: 100000000);
      container.read(gameProvider).update((s) {
        (s['clubAssets'] as Map<String, dynamic>)[_key] = <String, dynamic>{
          'owned': true,
          'tier': 3,
          'invested': 0,
          'tapCount': 0,
        };
      });
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('club-art-$_key')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('asset-ladder-$_key')), findsOneWidget);
      expect(find.text(t('club.upgrade_path').toUpperCase()), findsOneWidget);
      // The tier the club is on is marked, and every tier is listed.
      expect(find.byKey(const ValueKey('asset-ladder-now')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('asset-ladder-row-3'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('asset-ladder-row-$maxAssetTier'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      await settleSave(tester);
    });

    testWidgets('an unbuilt facility has no ladder to open yet', (
      tester,
    ) async {
      await pumpClub(tester, coins: 100000);
      await tester.tap(find.byKey(const ValueKey('club-art-$_key')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('asset-ladder-$_key')), findsNothing);
    });
  });

  group('what the club adds up to', () {
    testWidgets('nothing built is ONE line, not seven rows of x1.00', (
      tester,
    ) async {
      await pumpClub(tester, coins: 100000);
      expect(find.byKey(const ValueKey('club-stats-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('club-stats')), findsNothing);
    });

    testWidgets('and once something is, every figure is the ENGINE\'s', (
      tester,
    ) async {
      // Seven facilities at eight tiers each is too much arithmetic to do in
      // your head, and "what is all this worth" had no answer anywhere.
      final container = await pumpClub(tester, coins: 100000000);
      container.read(gameProvider).update((s) {
        (s['clubAssets']
            as Map<String, dynamic>)[AssetCategory.merch] = <String, dynamic>{
          'owned': true,
          'tier': 4,
          'invested': 0,
          'tapCount': 0,
        };
      });
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(find.byKey(const ValueKey('club-stats')), findsOneWidget);
      // Merch is +5% idle income a tier, so four tiers is x1.20.
      final income = container
          .read(clubStatsProvider)
          .firstWhere((r) => r.key == 'income');
      expect(income.value, '×1.20');
      expect(find.text('×1.20'), findsOneWidget);
    });

    testWidgets('a row explains itself on a tap', (tester) async {
      // The hints are written and shipped, and were unreachable.
      final container = await pumpClub(tester, coins: 100000000);
      container.read(gameProvider).update((s) {
        (s['clubAssets'] as Map<String, dynamic>)[AssetCategory.merch] =
            <String, dynamic>{'owned': true, 'tier': 1};
      });
      await tester.pumpAndSettle();
      await settleSave(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('club-stat-income')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('club-stat-income')));
      await tester.pumpAndSettle();
      expect(find.text(t('club.stats.income_hint')), findsOneWidget);
    });
  });

  testWidgets('the WHOLE card opens the upgrade path', (tester) async {
    // Only the artwork answered a tap, so the sheet holding every tier was
    // hidden behind a 64px strip.
    final container = await pumpClub(tester, coins: 100000000);
    container.read(gameProvider).update((s) {
      (s['clubAssets'] as Map<String, dynamic>)[_key] = <String, dynamic>{
        'owned': true,
        'tier': 2,
        'invested': 0,
        'tapCount': 0,
      };
    });
    await tester.pumpAndSettle();
    await settleSave(tester);

    // The card's own name, which is nowhere near the artwork.
    await tester.tap(find.text(t('asset.$_key.name')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('asset-ladder-$_key')), findsOneWidget);
  });
  testWidgets('THE CARDS ARE SOLID, AND THE PAGE HAS NO BACKDROP', (
    tester,
  ) async {
    // **Both are reversals, and both were rejected on sight.** The cards went
    // to `GlassPanel` on the reasoning that it is the app's one answer to "a
    // thing on the sky" — true of the Play screen and the full-time report, and
    // not of this page, which has no sky. The tint read as a dark gradient
    // across a card in LIGHT mode, which is the one place it cannot; a sky was
    // then added behind it to give the blur something to do, and that was
    // worse.
    await pumpClub(tester);
    expect(find.byKey(const ValueKey('club-backdrop')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('club-screen')),
        matching: find.byType(GlassPanel),
      ),
      findsNothing,
      reason: 'the asset cards are glass again',
    );
  });


  testWidgets('THE BUY BUTTON IS THE CURRENCY\'S COLOUR', (tester) async {
    // Coins yellow, gems blue, ads orange, real money green — stated as a rule
    // and true everywhere the shop draws a price. A facility is bought with
    // COINS and this was a flat `ElevatedButton` with none of the
    // three-dimensional face the `.store-3d` treatment gives every other price.
    await pumpClub(tester, coins: 999999);
    expect(
      tester
          .widget<StoreButton>(find.byKey(const ValueKey('club-action-$_key')))
          .tone,
      StoreTone.coin,
    );
  });

  group('the app\'s own art, not emoji', () {
    testWidgets('THE MAXED BADGE WAS HARDCODED ENGLISH', (tester) async {
      // An emoji star beside a word no catalogue could translate, on a badge
      // that ships in ten languages. `club.maxed` is the shipped string.
      await pumpClub(tester, mutate: (s) {
        final assets = s['clubAssets'] as Map<String, dynamic>;
        assets['STADIUM'] = <String, dynamic>{
          'owned': true,
          'tier': maxAssetTier,
          'tapCount': 0,
        };
      });
      expect(find.text(t('club.maxed')), findsWidgets);
      expect(find.textContaining('MAX'), findsNothing);
      expect(find.textContaining('★'), findsNothing);
    });

    testWidgets('and the buy button wears the set\'s coin', (tester) async {
      // Every other priced control in the app wears `GameIcon('coin')`; this
      // one — the most-pressed control on the screen — wore a 💰.
      await pumpClub(tester, coins: 1000000);
      expect(find.textContaining('💰'), findsNothing);
      expect(find.text(t('club.build')), findsNothing, reason: 'it has a price');
      expect(find.textContaining(t('club.build')), findsWidgets);
    });

    testWidgets('AND SO DOES THE SHORTFALL, mid-sentence', (tester) async {
      // The last coin bag on a priced control, and it was left there on the
      // reasoning that a `String` cannot carry a widget. True, and beside the
      // point: `{coin}` sits mid sentence — "Need {coin} {amount} more" — and
      // moves with the language, so what it needed was not a leading glyph but
      // a SLOT the coin is drawn into where the translator put it. Reported
      // from the couch.
      await pumpClub(tester, coins: 0);
      final button = find.byKey(const ValueKey('club-action-$_key'));
      expect(button, findsOneWidget);
      expect(find.textContaining('💰'), findsNothing);
      // The slot itself must never reach a reader, or a screen reader.
      expect(find.textContaining(coinSlot), findsNothing);
      // And the coin is a real one, inside the label rather than in front of
      // it: nothing was handed to `leading`.
      expect(tester.widget<StoreButton>(button).leading, isNull);
      expect(
        find.descendant(of: button, matching: find.byType(CoinIcon)),
        findsOneWidget,
      );
    });
  });
}
