/// What repaints when one thing on the screen moves.
///
/// Profiled on a phone in profile mode: 658 render objects painted on every one
/// of 118 frames a second — the next-match card, the dock, the HUD, the tab bar
/// — to animate a manager's eyes. Nothing above the rig was a `RepaintBoundary`,
/// so his tick dirtied the page. The hook here is the one the inspector's own
/// paint profiling uses: a render object is in the set when its PARENT painted
/// it, so a child appearing means the layer round it repainted.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugOnProfilePaint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/save_slots.dart';
import 'package:merge_empire_fc/state/save_store.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/next_match_card.dart';
import 'package:merge_empire_fc/ui/screens/match/play_button.dart';
import 'package:merge_empire_fc/ui/shell/app_shell.dart';
import 'package:merge_empire_fc/ui/shell/tab_bar.dart';
import 'package:merge_empire_fc/ui/theme/theme_providers.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/util/time.dart';

/// A save with no boot popup queued, so nothing covers the page and mutes it.
Map<String, dynamic> _quietSave() {
  final s = createDefaultState();
  s['dailyReward'] = <String, dynamic>{
    'cycleDay': 1,
    'lastClaimDayKey': dateString(),
    'streak': 1,
    'longestStreak': 1,
    'totalClaims': 1,
    'lastAutoPopupDayKey': dateString(),
  };
  return s;
}

/// The shell with motion ON, which is the whole point: every other shell test
/// declares reduced motion so it can settle, and reduced motion is exactly the
/// setting under which none of this costs anything.
Future<ProviderContainer> pumpLiveShell(
  WidgetTester tester, {
  Widget? home,
  Map<String, dynamic>? save,
}) async {
  final container = ProviderContainer(
    overrides: [
      saveStoreProvider.overrideWithValue(
        MemorySaveStore({saveKeyPrimary: jsonEncode(save ?? _quietSave())}),
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
          home: home ?? const AppShell(),
        ),
      ),
    ),
  );
  // Nothing settles with the walker alive. Two seconds is past every entrance
  // and the first save; after this the only thing moving is what moves forever.
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return container;
}

/// Every render object some parent painted during one frame.
Future<Set<RenderObject>> paintedInOneFrame(WidgetTester tester) async {
  final painted = <RenderObject>{};
  debugOnProfilePaint = painted.add;
  try {
    await tester.pump(const Duration(milliseconds: 16));
  } finally {
    debugOnProfilePaint = null;
  }
  return painted;
}

void main() {
  tearDown(() {
    debugOnProfilePaint = null;
    resetPopupQueue();
  });

  testWidgets('the diorama moving does not repaint the page round it', (
    tester,
  ) async {
    await pumpLiveShell(tester);
    final painted = await paintedInOneFrame(tester);

    expect(
      painted,
      contains(tester.renderObject(find.byType(ManagerWalker))),
      reason: 'he is alive between gestures, so the frame has to have drawn him',
    );
    final still = <String, Finder>{
      'the next-match card': find.byType(NextMatchCard),
      'the dock rail': find.byKey(const ValueKey('dock-rail')),
      'the play button': find.byType(PlayMatchButton),
      'the HUD': find.byKey(const ValueKey('hud-layer')),
      'the tab bar': find.byType(ShellTabBar),
    };
    for (final MapEntry(key: name, value: finder) in still.entries) {
      expect(
        painted,
        isNot(contains(tester.renderObject(finder))),
        reason: '$name repainted in a frame where only the diorama moved',
      );
    }
  });
}
