/// The free shelf — everything a rewarded video buys.
///
/// **The gate was live and the ad was not, and that was the whole difficulty**:
/// two true statements about the same tile can still contradict each other in
/// front of a player. There is an ad now, so these tests are about what a video
/// GRANTS and what stops one being offered.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/free_shelf_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_free.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/time.dart';

import 'shop_helpers.dart';

/// An SDK that answers however the test needs it to.
class _Ads implements RewardedAds {
  _Ads(this.outcome);

  AdOutcome outcome;
  final List<String> shown = [];

  @override
  Future<AdOutcome> show(String placement) async {
    shown.add(placement);
    return outcome;
  }

  @override
  void prepare(String placement) {}
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Ads ads, {
  void Function(Map<String, dynamic>)? mutate,
}) async {
  final container = shopContainer(
    mutate ?? (_) {},
    overrides: [rewardedAdsProvider.overrideWithValue(ads)],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      // The theme carries `KitTheme`, which the tiles read — a bare
      // `MaterialApp` throws on the null check.
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const Scaffold(
            body: SingleChildScrollView(child: FreeShelfSection()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  tearDown(resetLocale);

  testWidgets('AN AD BUTTON SAYS SO ON THE BUTTON', (tester) async {
    // The tone was already the ad yellow and the label is a VERB ("Claim"),
    // which on its own is a free thing rather than a thing you watch a video
    // for. The disclosure has to come from somewhere.
    await pumpShopWidget(tester, (_) {}, FreeShelfSection.new);
    final button = tester.widget<StoreButton>(
      find.byKey(const ValueKey('shop-buy-ad-lucky-boot')).first,
    );
    expect(button.tone, StoreTone.ad);
    expect(button.leading, isA<GameIcon>());
    expect((button.leading! as GameIcon).name, 'video');
  });

  testWidgets('and both rows of the shelf are there', (tester) async {
    await pumpShopWidget(tester, (_) {}, FreeShelfSection.new);
    expect(
      find.byKey(const ValueKey('shop-tile-ad-match-cooldown')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('shop-tile-ad-lucky-boot')), findsOneWidget);
  });

  testWidgets('"ALREADY READY" IS TRUE AGAIN, and it is on its own', (
    tester,
  ) async {
    // It went while there was no ad, because the gate really was open and there
    // was still nothing to watch — the tile read "Already ready" with "Coming
    // soon" directly under it. There is something to watch now.
    await _pump(tester, _Ads(AdOutcome.rewarded));
    expect(find.text(t('shop.already_ready')), findsWidgets);
    expect(find.text(t('settings.comingSoon')), findsNothing);
  });

  group('a watched video GRANTS', () {
    testWidgets('the lucky boot, and the boot is what the SAVE says', (
      tester,
    ) async {
      final ads = _Ads(AdOutcome.rewarded);
      final c = await _pump(tester, ads);
      expect(luckyBootHeld(c.read(gameProvider).state), isFalse);

      await tester.tap(
        find.byKey(const ValueKey('shop-buy-ad-lucky-boot')).first,
      );
      await tester.pumpAndSettle();
      await settleSave(tester);

      expect(ads.shown, [luckyBootPlacement]);
      expect(luckyBootHeld(c.read(gameProvider).state), isTrue);
    });

    testWidgets('and the cooldown skip, which spends one of three', (
      tester,
    ) async {
      final ads = _Ads(AdOutcome.rewarded);
      final c = await _pump(tester, ads);
      await tester.tap(
        find.byKey(const ValueKey('shop-buy-ad-match-cooldown')).first,
      );
      await tester.pumpAndSettle();
      await settleSave(tester);

      final state = c.read(gameProvider).state!;
      expect(ads.shown, [cooldownPlacement]);
      expect(matchCooldownFree(state), isTrue);
      expect(matchCooldownAdsUsed(state), 1);
    });
  });

  testWidgets('A CLOSED VIDEO GRANTS NOTHING', (tester) async {
    final ads = _Ads(AdOutcome.dismissed);
    final c = await _pump(tester, ads);
    await tester.tap(find.byKey(const ValueKey('shop-buy-ad-lucky-boot')).first);
    await tester.pumpAndSettle();
    await settleSave(tester);
    expect(luckyBootHeld(c.read(gameProvider).state), isFalse);
  });

  testWidgets('and a boot already on the shelf is HELD, not offered twice', (
    tester,
  ) async {
    // A second would overwrite the first, which is a video spent on nothing.
    final ads = _Ads(AdOutcome.rewarded);
    await _pump(
      tester,
      ads,
      mutate: (s) =>
          (s['shop'] as Map<String, dynamic>)['luckyBootReady'] = true,
    );
    expect(find.text(t('shop.active')), findsWidgets);
    final button = tester.widget<StoreButton>(
      find.byKey(const ValueKey('shop-buy-ad-lucky-boot')).first,
    );
    expect(button.onTap, isNull);
  });

  testWidgets('AND A RUNNING BOOST COUNTS DOWN rather than selling again', (
    tester,
  ) async {
    await _pump(
      tester,
      _Ads(AdOutcome.rewarded),
      mutate: (s) => (s['boosts'] as Map<String, dynamic>)
          ['matchCooldownFreeUntil'] = now() + 3 * 60 * 1000,
    );
    expect(find.textContaining('3m'), findsWidgets);
    final button = tester.widget<StoreButton>(
      find.byKey(const ValueKey('shop-buy-ad-match-cooldown')).first,
    );
    expect(button.onTap, isNull);
  });

  testWidgets('and three a day is the cap on the cooldown skip', (tester) async {
    await _pump(
      tester,
      _Ads(AdOutcome.rewarded),
      mutate: (s) => (s['shop'] as Map<String, dynamic>)
        ..['matchCooldownAdDay'] = dateString(now())
        ..['matchCooldownAdCount'] = matchCooldownAdCapPerDay,
    );
    final button = tester.widget<StoreButton>(
      find.byKey(const ValueKey('shop-buy-ad-match-cooldown')).first,
    );
    expect(button.onTap, isNull);
    expect(find.text(t('shop.daily_cap')), findsWidgets);
  });
}
