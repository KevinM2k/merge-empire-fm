/// **"It says I earned something, and that I was away for 0s."**
///
/// Reported from a device. The card was right about the money and wrong about
/// the hour, because the two came from different readings of `lastSeen`: the
/// save carried the real one and the boot had already stamped over it by the
/// time anything asked.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/main.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/providers/low_end_device.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/ui/popups/welcome_back_card.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';

Map<String, dynamic> _awaySince(Duration away) {
  final save = createDefaultState();
  save['tutorial'] = <String, dynamic>{'done': true, 'step': 0};
  save['lastSeen'] =
      DateTime.now().millisecondsSinceEpoch - away.inMilliseconds;
  // **A SQUAD, because an empty grid earns nothing.** `processOfflineEarnings`
  // returns zero for a save with no players — quite right, and it means a
  // default state can never raise the card this test is about.
  final cells = (save['grid'] as Map<String, dynamic>)['cells'] as List;
  for (var i = 0; i < 4 && i < cells.length; i++) {
    cells[i] = <String, dynamic>{
      'instanceId': 'card-$i',
      'definitionId': 'player_t1_gk',
    };
  }
  return save;
}

class _FixedQuality extends LowEndDevice {
  @override
  bool build() => false;
}

void main() {
  tearDown(resetPopupQueue);

  testWidgets('AN HOUR AWAY IS AN HOUR, through a real boot', (tester) async {
    // **Through `MergeEmpireApp`, not by calling the engine.** The engine was
    // never wrong: `processOfflineEarnings` measures `now() - lastSeen` and its
    // own unit tests pass on a hand-built map. What was wrong was WHEN it ran.
    // It was computed in the popup host's first post-frame callback, by which
    // point the age-signal sweep, the save debounce and the cloud restore have
    // all had a chance to call `saveNow` — and every one of those stamps
    // `lastSeen`. Measured through a real boot, a save seeded an hour in the
    // past came back with `lastSeen` moved forward 3,600,859ms and a window of
    // ONE MILLISECOND.
    //
    // So this test boots the app. A version of it that built the state by hand
    // would have passed against the broken build, which is the whole reason it
    // is written this way.
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // **The frame sampler, pinned.** It re-arms a 2.5s timer off its own
          // firing, so a widget test can never drain it — and this test is
          // about `lastSeen`, not about how fast the machine running it is.
          lowEndDeviceProvider.overrideWith(_FixedQuality.new),
          saveStoreProvider.overrideWithValue(
            MemorySaveStore({
              saveKeyPrimary: jsonEncode(_awaySince(const Duration(hours: 1))),
            }),
          ),
        ],
        child: const MergeEmpireApp(),
      ),
    );
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(WelcomeBackCard).evaluate().isNotEmpty) break;
    }

    // **Asked of the CARD, not of the engine.** What broke was the value that
    // reached the player, and every link between the save and that value is
    // part of the bug's surface: the reading, who holds it, and when the host
    // asks for it. Reading it off the widget is the only assertion that covers
    // the lot.
    final card = find.byType(WelcomeBackCard);
    expect(card, findsOneWidget, reason: 'the welcome-back card never opened');
    expect(
      tester.widget<WelcomeBackCard>(card).offline.offlineMs,
      greaterThan(const Duration(minutes: 55).inMilliseconds),
      reason: 'the window collapsed — this is the "0s" the player saw',
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('and a save that was never away is owed nothing', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // **The frame sampler, pinned.** It re-arms a 2.5s timer off its own
          // firing, so a widget test can never drain it — and this test is
          // about `lastSeen`, not about how fast the machine running it is.
          lowEndDeviceProvider.overrideWith(_FixedQuality.new),
          saveStoreProvider.overrideWithValue(
            MemorySaveStore({
              saveKeyPrimary: jsonEncode(_awaySince(Duration.zero)),
            }),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const MergeEmpireApp();
          },
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(gameRunnerProvider).pendingOffline!.earned, 0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('AND THE CEILING STILL HOLDS, at three days away', (tester) async {
    // `Idle.maxOfflineMs` is the cap the card's own note is about.
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // **The frame sampler, pinned.** It re-arms a 2.5s timer off its own
          // firing, so a widget test can never drain it — and this test is
          // about `lastSeen`, not about how fast the machine running it is.
          lowEndDeviceProvider.overrideWith(_FixedQuality.new),
          saveStoreProvider.overrideWithValue(
            MemorySaveStore({
              saveKeyPrimary: jsonEncode(_awaySince(const Duration(days: 3))),
            }),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const MergeEmpireApp();
          },
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      container.read(gameRunnerProvider).pendingOffline!.offlineMs,
      Idle.maxOfflineMs,
    );
    await tester.pump(const Duration(seconds: 3));
  });
}
