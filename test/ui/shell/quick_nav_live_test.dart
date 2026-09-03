/// What the phone shows while it is still open — its dots, and its battery.
///
/// **Every door on the phone opens a sheet OVER it**, and closing one lands the
/// player back on the phone rather than on the pitch — that is deliberate, and
/// it is what made this a bug: the menu was built once when the phone was
/// opened and handed to the route as a list of plain `bool`s, so a tile went on
/// nagging about something the player had just dealt with behind it. Reported
/// from the couch: "I finished all training, went back to the phone and red dot
/// was still on it... it was only when I changed tabs and came back that it
/// went" — putting the phone away and opening it again is what rebuilt the
/// list. The battery was frozen by exactly the same snapshot and is fixed with
/// it: a pip spent behind the phone left it charged.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/energy_engine.dart';
import 'package:merge_empire_fc/engine/mini_games_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/hud/hud.dart' show energyMaxProvider;
import 'package:merge_empire_fc/ui/popups/quick_nav_menu.dart';
import 'package:merge_empire_fc/ui/screens/minigames/minigames_providers.dart';
import 'package:merge_empire_fc/ui/shell/shell_quick_nav.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';

/// Opens the phone over a real save, and hands back the container behind it so
/// a test can play a drill without leaving the screen.
Future<ProviderContainer> openPhone(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(createDefaultState())}),
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
            body: Builder(
              builder: (inner) => Center(
                child: ElevatedButton(
                  key: const ValueKey('open'),
                  // Exactly what the dock does — see `home_dock.dart`: the
                  // doors are opened from THIS screen, the tiles are read with
                  // the menu's own ref.
                  onPressed: () => showQuickNavMenu(
                    inner,
                    groups: (menuRef) => quickNavGroups(inner, menuRef),
                    battery: (menuRef) {
                      final max = menuRef.watch(energyMaxProvider);
                      return max <= 0
                          ? 1
                          : menuRef.watch(energyProvider) / max;
                    },
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('A DRILL PLAYED BEHIND THE PHONE PUTS THE PHONE\'S DOT OUT', (
    tester,
  ) async {
    final container = await openPhone(tester);
    // A default save is on Training tier 0, which unlocks the penalty drill and
    // nothing else — and a drill that has never been played is ready, so the
    // Training tile opens nagging.
    expect(container.read(miniGamesReadyProvider), 1);
    expect(
      find.byKey(const ValueKey('quick-nav-dot-subnav.training')),
      findsOneWidget,
    );

    // The drill, played in the sheet that opened over the phone. The stamp goes
    // on when the session STARTS, which is what the sheet does.
    final game = container.read(gameProvider);
    startMiniGame(game.state!, MiniGameKind.penalty);
    game.notifyChanged();
    await tester.pump();

    // **The phone is still open**, and the dot is gone: no tab change, no
    // second open.
    expect(find.byKey(const ValueKey('quick-nav-phone')), findsOneWidget);
    expect(container.read(miniGamesReadyProvider), 0);
    expect(
      find.byKey(const ValueKey('quick-nav-dot-subnav.training')),
      findsNothing,
    );
  });

  testWidgets('and the tile is still a door once it has gone quiet', (
    tester,
  ) async {
    // The dot going out must not take the tile with it — the drills are still
    // there to look at, cooling down.
    final container = await openPhone(tester);
    final game = container.read(gameProvider);
    startMiniGame(game.state!, MiniGameKind.penalty);
    game.notifyChanged();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('quick-nav-subnav.training')),
      findsOneWidget,
    );
  });

  testWidgets('AND A PIP SPENT BEHIND THE PHONE COMES OFF ITS BATTERY', (
    tester,
  ) async {
    // Same freeze, other end of the same screen: the charge was worked out in
    // the dock's `onTap` and handed over as a `double`, so the phone showed
    // whatever the energy was when it was opened.
    final container = await openPhone(tester);
    expect(find.text('100%'), findsOneWidget);

    final game = container.read(gameProvider);
    expect(spendEnergy(game.state!, 8).ok, isTrue);
    game.notifyChanged();
    await tester.pump();

    // Two pips of ten, which is also the red the couch asked for — see
    // `batteryLow`.
    expect(find.byKey(const ValueKey('quick-nav-phone')), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);
    expect(find.text('100%'), findsNothing);
  });
}
