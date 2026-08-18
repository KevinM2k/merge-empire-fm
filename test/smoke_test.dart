/// The app boots, with a save store in memory rather than on a device.
///
/// `main()` opens the real store before `runApp`, so the widget under test is
/// the app WITHOUT that step — the override here is what the platform store
/// would have provided.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/main.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_store.dart';

void main() {
  testWidgets('app boots and renders a MaterialApp', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [saveStoreProvider.overrideWithValue(MemorySaveStore())],
        child: const MergeEmpireApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
    // Booted onto a default state: the club has no name until the picker runs,
    // but the save exists and the loop is running.
    expect(container(tester).read(clubNameProvider), '');
    expect(container(tester).read(gameRunnerProvider).running, isTrue);
  });
}

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
