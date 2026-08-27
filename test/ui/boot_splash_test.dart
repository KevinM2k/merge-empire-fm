/// The boot splash: it covers the app, fills its bar, then leaves.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/boot_splash.dart';

void main() {
  testWidgets('names the game, says LOADING and draws a bar', (tester) async {
    await tester.pumpWidget(
      const BootSplash(child: SizedBox(key: Key('app'))),
    );
    await tester.pump();
    expect(find.text('MERGE EMPIRE'), findsOneWidget);
    expect(find.text('FOOTBALL MANAGER'), findsOneWidget);
    expect(find.text(t('common.loading').toUpperCase()), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsOneWidget);
  });

  testWidgets('the bar fills across the window rather than snapping', (
    tester,
  ) async {
    await tester.pumpWidget(
      const BootSplash(child: SizedBox(key: Key('app'))),
    );
    await tester.pump();
    double factor() => tester
        .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .widthFactor!;
    expect(factor(), 0);
    await tester.pump(splashWindow ~/ 2);
    expect(factor(), closeTo(0.5, 0.05));
    await tester.pump(splashWindow ~/ 2);
    expect(factor(), 1);
  });

  testWidgets('leaves the tree, so it stops eating taps', (tester) async {
    await tester.pumpWidget(
      const BootSplash(child: SizedBox(key: Key('app'))),
    );
    // The logo pulse never stops, so `pumpAndSettle` would time out — this
    // waits out the window, the hold and the fade by hand.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(FractionallySizedBox), findsNothing);
    expect(find.byKey(const Key('app')), findsOneWidget);
  });

  testWidgets('AND THE APP UNDER IT IS NOT RE-PARENTED WHEN IT GOES', (
    tester,
  ) async {
    // Returning the bare child once the splash had gone swapped the Stack out
    // from over the whole app — every widget in it deactivated and re-mounted
    // INSIDE that build, the grid's `deactivate` wrote a provider mid-build,
    // and 2,600 "setState() called during build" errors followed on every
    // launch. The Element under the splash has to be the same one throughout.
    await tester.pumpWidget(
      const BootSplash(child: SizedBox(key: Key('app'))),
    );
    final before = tester.element(find.byKey(const Key('app')));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(FractionallySizedBox), findsNothing);
    expect(
      identical(tester.element(find.byKey(const Key('app'))), before),
      isTrue,
      reason: 'the app was rebuilt from scratch when the splash left',
    );
  });

  testWidgets('a zero window never shows it at all', (tester) async {
    await tester.pumpWidget(
      const BootSplash(window: Duration.zero, child: SizedBox(key: Key('app'))),
    );
    await tester.pump();
    expect(find.byType(FractionallySizedBox), findsNothing);
  });
}
