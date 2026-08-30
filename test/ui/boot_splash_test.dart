/// The boot splash: it covers the app, fills its bar, then leaves.
library;

import 'dart:async';

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

  group('AND IT WAITS FOR THE RESTORE, but never for long', () {
    // **The half of `setupSplash` the port never had.** The JS fades out when
    // the cloud-save restore completes; the port faded out on a fixed clock, so
    // the two halves of the boot ran past each other — a restore landing a beat
    // late swapped the whole save out from under a player already looking at
    // their squad.
    Future<void> pumpGated(
      WidgetTester tester,
      Future<void> gate, {
      Duration timeout = const Duration(seconds: 6),
    }) async {
      await tester.pumpWidget(
        BootSplash(
          window: const Duration(milliseconds: 100),
          gate: gate,
          gateTimeout: timeout,
          child: const SizedBox(key: Key('app')),
        ),
      );
      await tester.pump();
    }

    bool splashUp(WidgetTester tester) =>
        find.text('MERGE EMPIRE').evaluate().isNotEmpty;

    /// The logo pulse never stops, so `pumpAndSettle` would time out — this
    /// waits out whatever is left of the window, the hold and the fade by hand.
    Future<void> windDown(WidgetTester tester) async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('a restore still in the air HOLDS it', (tester) async {
      final restore = Completer<void>();
      await pumpGated(tester, restore.future);
      // Well past the window, which used to be the whole answer.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(
        splashUp(tester),
        isTrue,
        reason: 'the save is still moving underneath it',
      );

      restore.complete();
      await windDown(tester);
      expect(splashUp(tester), isFalse);
    });

    testWidgets('AND A DEAD NETWORK CANNOT TRAP ANYONE THERE', (tester) async {
      // The rule matters more than the gate: whatever the restore is doing,
      // the game opens.
      final never = Completer<void>();
      addTearDown(() => never.complete());
      await pumpGated(
        tester,
        never.future,
        timeout: const Duration(milliseconds: 300),
      );
      await windDown(tester);
      expect(splashUp(tester), isFalse, reason: 'it timed out and went');
    });

    testWidgets('a restore that THREW is still a restore that finished', (
      tester,
    ) async {
      // Failed WHILE the splash was up, which is the real sequence: the
      // handler is attached in `initState`, so nothing is ever unhandled.
      final restore = Completer<void>();
      await pumpGated(tester, restore.future);
      restore.completeError(StateError('offline'));
      await windDown(tester);
      expect(splashUp(tester), isFalse);
    });

    testWidgets('and a restore that lands instantly does NOT cut the window', (
      tester,
    ) async {
      // A splash that flashes past in 80ms is the thing the window exists to
      // prevent, so the gate is awaited after the bar rather than raced with it.
      await pumpGated(tester, Future<void>.value());
      await tester.pump(const Duration(milliseconds: 40));
      expect(splashUp(tester), isTrue);
      await windDown(tester);
      expect(splashUp(tester), isFalse);
    });
  });

  testWidgets('a zero window never shows it at all', (tester) async {
    await tester.pumpWidget(
      const BootSplash(window: Duration.zero, child: SizedBox(key: Key('app'))),
    );
    await tester.pump();
    expect(find.byType(FractionallySizedBox), findsNothing);
  });
}
