/// Shared setup for the Shop tests.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

ProviderContainer shopContainer(
  void Function(Map<String, dynamic> state) mutate,
) {
  final state = createDefaultState();
  mutate(state);
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.read(gameProvider).load();
  return container;
}

/// [scroll] off for anything that fills the height it is GIVEN — a sheet — which
/// a scroll view cannot provide.
Future<ProviderContainer> pumpShopWidget(
  WidgetTester tester,
  void Function(Map<String, dynamic> state) mutate,
  Widget Function() build, {
  bool scroll = true,
}) async {
  final container = shopContainer(mutate);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: ref.watch(appThemeProvider),
          home: Scaffold(
            body: scroll ? SingleChildScrollView(child: build()) : build(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Every write arms the 2s debounced save. Pump past it, or the test ends with
/// a timer still pending and the binding rightly complains.
Future<void> settleSave(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
