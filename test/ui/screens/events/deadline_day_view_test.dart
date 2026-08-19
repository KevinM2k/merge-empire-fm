/// Arriving on the trading floor.
///
/// The window being open IS the invitation, so the screen opens the session on
/// the way in — and it used to do that from `initState`, which is DURING a
/// build. Opening a session writes to the save, the save bumps
/// `saveRevisionProvider`, and Riverpod refuses a provider write while the tree
/// is building. In release the assertion is compiled out; in debug the screen
/// threw on the way in and the player landed on the intro instead of the floor.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/game_state.dart' show saveDebounceMs;
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/events/event_screen.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

void main() {
  tearDown(resetLocale);

  testWidgets('opens the session without throwing, and lands on the floor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = createDefaultState();
    final events = state['events'] as Map<String, dynamic>;
    // Forced outside the real calendar — the window opened on the last whole
    // hour, exactly as a dev override does on a device.
    events['devOverride'] = 'deadline_day';
    events['active'] = ['deadline_day'];

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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const EventScreen(),
          ),
        ),
      ),
    );
    // The frame that opens the session, then the one that paints the floor.
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('deadline-live')),
      findsOneWidget,
      reason: 'the window was open and the screen did not let us in',
    );

    // The screen owns a 1Hz ticker for the whole hour, and opening the session
    // armed the save debounce; both have to go before the binding checks for
    // pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: saveDebounceMs + 100));
  });
}
