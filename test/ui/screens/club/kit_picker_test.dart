/// The kit picker, and WHICH Stadium tier its padlocks are measured against.
///
/// The four tier-one kits were on offer before the Stadium existed, because the
/// picker gated on `stadiumTierProvider` — the number the stadium PHOTO and the
/// sky are drawn from, which floors at one so an unbuilt ground still has a
/// scene. A club that had never spent a coin on the Stadium therefore already
/// owned a third of what the facility advertises, and the card went on promising
/// them as what tier one would buy.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/club/club_screen.dart';
import 'package:merge_empire_fc/ui/screens/club/kit_picker.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// The first colour the Stadium's tier one is supposed to buy.
const String _tierOneKit = '#33691e';

Future<ProviderContainer> _pumpPicker(
  WidgetTester tester, {
  int stadiumTier = 0,
}) async {
  final state = createDefaultState();
  if (stadiumTier > 0) {
    (state['clubAssets'] as Map<String, dynamic>)[AssetCategory.stadium] =
        <String, dynamic>{
          'owned': true,
          'tier': stadiumTier,
          'invested': 0,
          'tapCount': 0,
        };
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

  await tester.tap(find.byKey(const ValueKey('kit-redesign')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('kit-picker')), findsOneWidget);
  return container;
}

String _kitOf(ProviderContainer c) =>
    ((c.read(gameProvider).state?['club'] as Map<String, dynamic>?)?['kitPrimaryColor']
        as String?) ??
    '';

void main() {
  tearDown(clearBus);

  testWidgets('an unbuilt Stadium unlocks NO kit colours', (tester) async {
    final container = await _pumpPicker(tester);
    final before = _kitOf(container);

    String? toast;
    on('toast:info', (v) => toast = '$v');

    await tester.tap(find.byKey(const ValueKey('kit-swatch-$_tierOneKit')));
    await tester.pumpAndSettle();

    expect(_kitOf(container), before, reason: 'a locked kit was worn');
    expect(toast, isNotNull, reason: 'a locked swatch says which tier');
  });

  testWidgets('and building it to tier one hands them over', (tester) async {
    final container = await _pumpPicker(tester, stadiumTier: 1);

    await tester.tap(find.byKey(const ValueKey('kit-swatch-$_tierOneKit')));
    await tester.pumpAndSettle();

    expect(_kitOf(container), _tierOneKit);
    // The save's own debounce, or the tree is disposed with it still pending.
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
  });

  testWidgets('the padlocks follow the ladder, tier by tier', (tester) async {
    // Every colour the table gates, checked against the tier it is gated at —
    // so a swatch cannot arrive early or fail to arrive at all.
    for (final entry in stadiumColourUnlocks.entries) {
      for (final colour in entry.value) {
        expect(kitUnlockTier(colour), entry.key, reason: colour);
      }
    }
    // And the grid shows all of them, locked ones included.
    await _pumpPicker(tester);
    for (final colour in allKitColours) {
      expect(
        find.byKey(ValueKey('kit-swatch-$colour'), skipOffstage: false),
        findsOneWidget,
        reason: colour,
      );
    }
  });
}
