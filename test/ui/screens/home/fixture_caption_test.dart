/// The caption over the next-match card.
///
/// It sits directly ON the sky with nothing behind it, so the one thing that
/// matters is that its ink follows the sky rather than being white in both
/// themes — which is what it was, because the sky used to run noon-to-midnight
/// on a clock and no theme colour survived both ends of that.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/fixture_caption.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

Future<void> pumpCaption(WidgetTester tester, {required bool light}) async {
  final state = createDefaultState();
  (state['settings'] as Map<String, dynamic>)['lightMode'] = light;
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
          home: const Scaffold(body: Center(child: FixtureCaption())),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The competition's own line — the biggest text in the caption.
double captionLuma(WidgetTester tester) {
  final style = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(FixtureCaption),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.style!)
      .reduce((a, b) => (a.fontSize ?? 0) >= (b.fontSize ?? 0) ? a : b);
  final c = style.color!;
  return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
}

void main() {
  testWidgets('is dark ink on a daylit sky and light ink on a night one', (
    tester,
  ) async {
    await pumpCaption(tester, light: true);
    final day = captionLuma(tester);
    await pumpCaption(tester, light: false);
    final night = captionLuma(tester);
    expect(day, lessThan(0.3), reason: 'white text on a bright sky again');
    expect(night, greaterThan(0.8));
  });

  testWidgets('and its halo inverts with the ink', (tester) async {
    // Dark text needs a light glow behind it and light text a dark one; without
    // that the line dissolves wherever the sky's gradient passes through its own
    // tone.
    for (final light in [true, false]) {
      await pumpCaption(tester, light: light);
      final style = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(FixtureCaption),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.style!)
          .firstWhere((s) => (s.shadows ?? []).isNotEmpty);
      final halo = style.shadows!.first.color;
      final haloLuma = 0.2126 * halo.r + 0.7152 * halo.g + 0.0722 * halo.b;
      expect(
        haloLuma > 0.5,
        light,
        reason: light
            ? 'a dark halo under dark ink'
            : 'a light halo under white',
      );
    }
  });
}
