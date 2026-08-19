/// The Shop screen: seven shelves, and the deep link that lands on two of them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_screen.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_section.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

import 'shop_helpers.dart';

Future<ProviderContainer> pumpShop(
  WidgetTester tester,
  void Function(Map<String, dynamic> state) mutate,
) async {
  final container = shopContainer(mutate);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: const Scaffold(body: ShopScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  tearDown(resetLocale);

  testWidgets('all seven sections are present', (tester) async {
    await pumpShop(tester, (_) {});
    for (final id in shopSectionOrder) {
      expect(
        find.byKey(ValueKey('shop-section-${id.name}'), skipOffstage: false),
        findsOneWidget,
        reason: id.name,
      );
    }
  });

  testWidgets('and in the order the JS ships', (tester) async {
    await pumpShop(tester, (_) {});
    final seen = <ShopSectionId>[];
    for (final id in shopSectionOrder) {
      final finder = find.byKey(
        ValueKey('shop-section-${id.name}'),
        skipOffstage: false,
      );
      if (finder.evaluate().isNotEmpty) seen.add(id);
    }
    expect(seen, shopSectionOrder);
  });

  testWidgets('the gems section survives owning the style vault', (
    tester,
  ) async {
    // A section that deletes itself takes the player's balance off screen.
    await pumpShop(tester, (s) {
      (s['shop'] as Map<String, dynamic>)['styleVault'] = true;
    });
    expect(
      find.byKey(const ValueKey('shop-section-gems'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('a coin deep link consumes the flag', (tester) async {
    final container = await pumpShop(tester, (_) {});
    container
        .read(shellControllerProvider.notifier)
        .deepLinkShop(ShopSection.coins);
    await tester.pumpAndSettle();
    expect(
      container.read(shellControllerProvider).pendingShopSection,
      isNull,
      reason: 'consumed, so a rebuild does not scroll again',
    );
  });

  testWidgets('a gem deep link consumes the flag too', (tester) async {
    final container = await pumpShop(tester, (_) {});
    container
        .read(shellControllerProvider.notifier)
        .deepLinkShop(ShopSection.gems);
    await tester.pumpAndSettle();
    expect(container.read(shellControllerProvider).pendingShopSection, isNull);
  });

  testWidgets('a link set before the screen exists is still honoured', (
    tester,
  ) async {
    // The tab can be built by the very frame that set the link.
    final container = shopContainer((_) {});
    container
        .read(shellControllerProvider.notifier)
        .deepLinkShop(ShopSection.gems);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeProvider),
            home: const Scaffold(body: ShopScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(shellControllerProvider).pendingShopSection, isNull);
  });
}
