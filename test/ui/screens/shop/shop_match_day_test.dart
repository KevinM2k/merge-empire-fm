/// The Match Day shelf — the two things that change how the next match goes.
///
/// **It was the FREE shelf and both tiles were rewarded videos.** That put the
/// two controls with the most effect on a match behind an advert, and made the
/// shelf's own name a promise about a price rather than a description of what
/// was on it. Both cost gems now — `matchDayGemCost` for the cooldown skip and
/// the dearer `luckyBootGemCost` for the Boot — so what these tests are about
/// is what a purchase GRANTS, what it charges, and what stops one being
/// offered.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/free_shelf_engine.dart';
import 'package:merge_empire_fc/engine/gem_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/time.dart';

import 'shop_helpers.dart';

/// A club with gems to spend. The shelf is priced in them now, so a save with
/// none makes every tile a refusal and says nothing about the grants.
void _withGems(Map<String, dynamic> s, [int gems = 20]) {
  final resources = s['resources'];
  if (resources is Map<String, dynamic>) resources['gems'] = gems;
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  void Function(Map<String, dynamic>)? mutate,
}) async {
  final container = shopContainer((s) {
    _withGems(s);
    mutate?.call(s);
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      // The theme carries `KitTheme`, which the tiles read — a bare
      // `MaterialApp` throws on the null check.
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const Scaffold(
            body: SingleChildScrollView(child: MatchDayTilesHarness()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

StoreButton _buttonFor(WidgetTester tester, String tile) =>
    tester.widget<StoreButton>(find.byKey(ValueKey('shop-buy-$tile')).first);

void main() {
  tearDown(resetLocale);

  testWidgets('both rows are there, and both are priced in GEMS', (
    tester,
  ) async {
    // **A PURCHASE MUST NEVER WEAR AN AD'S TONE**, which is the rule the
    // training sheet's skip-all already follows: blue is a price and yellow is
    // a video. Both tiles were yellow with a "Claim" verb on them.
    await _pump(tester);
    for (final tile in ['ad-match-cooldown', 'ad-lucky-boot']) {
      expect(find.byKey(ValueKey('shop-tile-$tile')), findsOneWidget);
      expect(_buttonFor(tester, tile).tone, StoreTone.gem);
    }
    // A price each, and NOT the same price: the Boot is the premium of the two
    // and the shelf has to say so.
    expect(find.text('$matchDayGemCost'), findsOneWidget);
    expect(find.text('$luckyBootGemCost'), findsOneWidget);
    expect(luckyBootGemCost, greaterThan(matchDayGemCost));
    // And nothing on the shelf says it is free or asks for a video any more.
    expect(find.text(t('shop.claim_cta')), findsNothing);
    expect(find.text(t('shop.daily_cap')), findsNothing);
  });

  testWidgets('AND THE BOOT IS NOT CALLED FREE', (tester) async {
    // The generated `shop.lucky_boot_ad_name` says "Free Lucky Boot" and its
    // description opens "Watch an ad ·". Neither is true, and both were on
    // screen. Replaced in `en_copy.dart` and the other nine overlays.
    await _pump(tester);
    expect(find.text(t('shop.lucky_boot_name')), findsOneWidget);
    expect(find.text(t('shop.lucky_boot_ad_name')), findsNothing);
    expect(
      find.textContaining(t('shop.lucky_boot_ad_desc')),
      findsNothing,
      reason: 'the tile still asks for a video',
    );
  });

  group('a purchase GRANTS, and charges', () {
    testWidgets('the lucky boot, and the boot is what the SAVE says', (
      tester,
    ) async {
      final c = await _pump(tester);
      expect(luckyBootHeld(c.read(gameProvider).state), isFalse);
      final before = getGems(c.read(gameProvider).state!);

      await tester.tap(
        find.byKey(const ValueKey('shop-buy-ad-lucky-boot')).first,
      );
      await tester.pumpAndSettle();
      await settleSave(tester);

      final state = c.read(gameProvider).state!;
      expect(luckyBootHeld(state), isTrue);
      expect(getGems(state), before - luckyBootGemCost);
    });

    testWidgets('and the cooldown skip', (tester) async {
      final c = await _pump(tester);
      final before = getGems(c.read(gameProvider).state!);
      await tester.tap(
        find.byKey(const ValueKey('shop-buy-ad-match-cooldown')).first,
      );
      await tester.pumpAndSettle();
      await settleSave(tester);

      final state = c.read(gameProvider).state!;
      expect(matchCooldownFree(state), isTrue);
      expect(getGems(state), before - matchDayGemCost);
    });
  });

  testWidgets('AND AN EMPTY WALLET GRANTS NOTHING', (tester) async {
    // `spendGems` returning false has to leave the grant unrun rather than
    // half-applied — which is why the charge and the grant are one update.
    final c = await _pump(tester, mutate: (s) => _withGems(s, 0));
    await tester.tap(find.byKey(const ValueKey('shop-buy-ad-lucky-boot')).first);
    await tester.pumpAndSettle();
    await settleSave(tester);
    final state = c.read(gameProvider).state!;
    expect(luckyBootHeld(state), isFalse);
    expect(getGems(state), 0);
  });

  testWidgets('and a boot already on the shelf is HELD, not sold twice', (
    tester,
  ) async {
    // A second would overwrite the first, which is two gems spent on nothing.
    final c = await _pump(
      tester,
      mutate: (s) =>
          (s['shop'] as Map<String, dynamic>)['luckyBootReady'] = true,
    );
    expect(find.text(t('shop.active')), findsWidgets);
    expect(_buttonFor(tester, 'ad-lucky-boot').onTap, isNull);
    expect(getGems(c.read(gameProvider).state!), 20);
  });

  testWidgets('AND A RUNNING BOOST COUNTS DOWN rather than selling again', (
    tester,
  ) async {
    await _pump(
      tester,
      mutate: (s) => (s['boosts'] as Map<String, dynamic>)
          ['matchCooldownFreeUntil'] = now() + 3 * 60 * 1000,
    );
    expect(find.textContaining('3m'), findsWidgets);
    expect(_buttonFor(tester, 'ad-match-cooldown').onTap, isNull);
  });

  testWidgets('AND THE DAY\'S THREE VIDEOS ARE NOT A CAP ANY MORE', (
    tester,
  ) async {
    // `matchCooldownAdCapPerDay` was a limit on VIEWS and it went with them.
    // The tile used to reprice to one gem past the third video; it is two gems
    // from the first one now, and a save that has already spent the old
    // allowance can still buy.
    final c = await _pump(
      tester,
      mutate: (s) => (s['shop'] as Map<String, dynamic>)
        ..['matchCooldownAdDay'] = dateString(now())
        ..['matchCooldownAdCount'] = matchCooldownAdCapPerDay,
    );
    expect(
      _buttonFor(tester, 'ad-match-cooldown').onTap,
      isNotNull,
      reason: 'the old video cap still closes the tile',
    );
    expect(find.text('$matchDayGemCost'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('shop-buy-ad-match-cooldown')).first,
    );
    await tester.pumpAndSettle();
    await settleSave(tester);
    expect(matchCooldownFree(c.read(gameProvider).state!), isTrue);
  });
}
