/// A press buzzes, and the switch in Settings is what stops it.
///
/// **THE WIRING IS THE WHOLE RISK HERE.** The service's own rules are checked in
/// `test/services/haptics_service_test.dart` with no widgets at all; what this
/// asks is the question that test cannot — whether anything ever calls it, and
/// whether the row in Settings reaches it. Both halves have been the bug before:
/// `trackEvent` was a finished engine nothing called.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/press_providers.dart';
import 'package:merge_empire_fc/services/haptics_service.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

class _Backend implements HapticsBackend {
  int calls = 0;

  @override
  Future<void> press() async => calls++;
}

void main() {
  late _Backend backend;

  setUp(() => backend = _Backend());

  /// The app's own theme, over one button, with the save the test asks for.
  Future<void> pump(WidgetTester tester, {bool? hapticsEnabled}) async {
    final state = createDefaultState();
    if (hapticsEnabled != null) {
      (state['settings'] as Map<String, dynamic>)['hapticsEnabled'] =
          hapticsEnabled;
    }
    final container = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(
          MemorySaveStore({saveKeyPrimary: jsonEncode(state)}),
        ),
        hapticsServiceProvider.overrideWithValue(
          HapticsService(backend: backend),
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
            home: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('A BUTTON BUZZES, off the same splash the click rides', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(backend.calls, 1);
  });

  testWidgets('AND THE SAVE\'S SWITCH IS WHAT STOPS IT', (tester) async {
    await pump(tester, hapticsEnabled: false);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(backend.calls, 0);
  });

  testWidgets('a save that has never heard of the key still buzzes', (
    tester,
  ) async {
    // The key is the port's own, so it is absent from `state_schema.dart` and
    // from every existing save — and unlike the interface CLICK, the absent key
    // means ON. See `press_providers.dart`.
    final state = createDefaultState();
    expect(
      (state['settings'] as Map<String, dynamic>).containsKey('hapticsEnabled'),
      isFalse,
    );
    await pump(tester);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(backend.calls, 1);
  });
}
